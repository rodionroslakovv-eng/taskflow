import 'package:drift/drift.dart';

import '../../../../constants/business_rules.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../models/app_database.dart';
import '../../../../models/relation_models.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/task.dart';

abstract class TaskLocalDataSource {
  Stream<List<TaskItemModel>> watchTasks(TaskFilter filter);
  Future<List<TaskItemModel>> getTasks(TaskFilter filter);
  Stream<TaskItemModel?> watchTask(int id);
  Future<TaskRow?> getTask(int id);

  Stream<List<HistoryModel>> watchHistory(int taskId);
  Future<List<HistoryRow>> getHistory(int taskId);
  Stream<HistoryRow?> watchLastUndoable(int taskId);

  Future<int> createTask({
    required String title,
    required String description,
    required int projectId,
    int? assigneeId,
    required TaskPriority priority,
    required TaskStatus status,
    DateTime? deadline,
    int? actorId,
  });

  Future<void> updateTask(
    int id, {
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  });

  Future<void> changePriority(int id, TaskPriority priority);
  Future<void> changeStatus(int id, TaskStatus newStatus, {int? actorId});
  Future<void> assignTask(int id, int? assigneeId, {int? actorId});
  Future<void> undoLastStatusChange(int taskId, {int? actorId});

  Future<void> softDelete(int id);
  Future<void> restore(int id);
  Future<void> deleteForever(int id);
}

class TaskLocalDataSourceImpl implements TaskLocalDataSource {
  TaskLocalDataSourceImpl(this._db);
  final AppDatabase _db;

  // ---------------- чтение ----------------

  JoinedSelectStatement<HasResultSet, dynamic> _query(TaskFilter f) {
    final t = _db.tasks;
    final u = _db.users;
    final p = _db.projects;
    final q = _db.select(t).join([
      leftOuterJoin(u, u.id.equalsExp(t.assigneeId)),
      innerJoin(p, p.id.equalsExp(t.projectId)),
    ]);

    Expression<bool> cond = f.onlyDeleted
        ? t.deletedAt.isNotNull()
        : t.deletedAt.isNull();
    if (f.projectId != null) cond = cond & t.projectId.equals(f.projectId!);
    if (f.assigneeId != null) cond = cond & t.assigneeId.equals(f.assigneeId!);
    if (f.status != null) cond = cond & t.status.equalsValue(f.status!);
    if (f.priority != null) cond = cond & t.priority.equalsValue(f.priority!);
    if (f.taskIds != null) cond = cond & t.id.isIn(f.taskIds!);
    final text = f.query.trim();
    if (text.isNotEmpty) {
      final pattern = '%${text.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      cond =
          cond &
          (t.title.like(pattern, escapeChar: r'\') |
              t.description.like(pattern, escapeChar: r'\'));
    }
    q.where(cond);

    final mode = f.ascending ? OrderingMode.asc : OrderingMode.desc;
    final first = switch (f.sort) {
      TaskSort.createdAt => OrderingTerm(expression: t.createdAt, mode: mode),
      TaskSort.deadline => OrderingTerm(
        expression: t.deadline,
        mode: mode,
        nulls: NullsOrder.last,
      ),
    };
    q.orderBy([first, OrderingTerm.desc(t.id)]);
    if (f.limit != null) q.limit(f.limit!, offset: f.offset);
    return q;
  }

  TaskItemModel _map(TypedResult r) => TaskItemModel(
    task: r.readTable(_db.tasks),
    assignee: r.readTableOrNull(_db.users),
    project: r.readTable(_db.projects),
  );

  @override
  Stream<List<TaskItemModel>> watchTasks(TaskFilter f) =>
      _query(f).map(_map).watch();

  @override
  Future<List<TaskItemModel>> getTasks(TaskFilter f) =>
      _query(f).map(_map).get();

  @override
  Stream<TaskItemModel?> watchTask(int id) {
    final t = _db.tasks;
    final u = _db.users;
    final p = _db.projects;
    final q = _db.select(t).join([
      leftOuterJoin(u, u.id.equalsExp(t.assigneeId)),
      innerJoin(p, p.id.equalsExp(t.projectId)),
    ])..where(t.id.equals(id));
    return q.map(_map).watchSingleOrNull();
  }

  @override
  Future<TaskRow?> getTask(int id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  @override
  Stream<List<HistoryModel>> watchHistory(int taskId) {
    final h = _db.taskHistory;
    final u = _db.users;
    final q =
        _db.select(h).join([leftOuterJoin(u, u.id.equalsExp(h.changedBy))])
          ..where(h.taskId.equals(taskId))
          ..orderBy([OrderingTerm.desc(h.id)]);
    return q
        .map(
          (r) => HistoryModel(entry: r.readTable(h), user: r.readTableOrNull(u)),
        )
        .watch();
  }

  @override
  Future<List<HistoryRow>> getHistory(int taskId) =>
      (_db.select(_db.taskHistory)
            ..where((h) => h.taskId.equals(taskId))
            ..orderBy([(h) => OrderingTerm.asc(h.id)]))
          .get();

  Selectable<HistoryRow> _lastUndoableQuery(
    int taskId,
  ) {
    final h = _db.taskHistory;
    return _db.select(h)
      ..where(
        (x) =>
            x.taskId.equals(taskId) &
            x.kind.equalsValue(HistoryKind.status) &
            x.undone.equals(false),
      )
      ..orderBy([(x) => OrderingTerm.desc(x.id)])
      ..limit(1);
  }

  @override
  Stream<HistoryRow?> watchLastUndoable(int taskId) =>
      _lastUndoableQuery(taskId).watchSingleOrNull();

  // ---------------- проверки ----------------

  Future<void> _assertMember(int projectId, int userId) async {
    final m = _db.projectMembers;
    final row =
        await (_db.select(m)..where(
              (x) => x.projectId.equals(projectId) & x.userId.equals(userId),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw const ValidationException('Исполнитель не состоит в проекте задачи');
    }
  }

  /// У исполнителя не может быть более [kMaxTasksPerDeadline] незавершённых
  /// задач с одним дедлайном. Проверка выполняется запросом к БД.
  Future<void> _assertWorkload(
    int? assigneeId,
    DateTime? deadline, {
    int? excludeTaskId,
  }) async {
    if (assigneeId == null || deadline == null) return;
    final start = DateTime(deadline.year, deadline.month, deadline.day);
    final end = DateTime(deadline.year, deadline.month, deadline.day + 1);
    final t = _db.tasks;
    final cnt = t.id.count();
    Expression<bool> cond =
        t.assigneeId.equals(assigneeId) &
        t.deletedAt.isNull() &
        t.status.isInValues([TaskStatus.todo, TaskStatus.inProgress]) &
        t.deadline.isBiggerOrEqualValue(start) &
        t.deadline.isSmallerThanValue(end);
    if (excludeTaskId != null) cond = cond & t.id.equals(excludeTaskId).not();
    final q = _db.selectOnly(t)
      ..addColumns([cnt])
      ..where(cond);
    final n = await q.map((r) => r.read(cnt)!).getSingle();
    if (n >= kMaxTasksPerDeadline) {
      throw ValidationException(
        'У исполнителя уже $n незавершённых задач с этим дедлайном (максимум $kMaxTasksPerDeadline)',
      );
    }
  }

  Future<void> _addHistory({
    required int taskId,
    required HistoryKind kind,
    TaskStatus? oldStatus,
    required TaskStatus newStatus,
    int? actorId,
    String? note,
  }) async {
    await _db
        .into(_db.taskHistory)
        .insert(
          TaskHistoryCompanion.insert(
            taskId: taskId,
            kind: kind,
            oldStatus: Value(oldStatus),
            newStatus: newStatus,
            changedBy: Value(actorId),
            changedAt: Value(DateTime.now()),
            note: Value(note),
          ),
        );
  }

  Future<TaskRow> _require(int id) async {
    final task = await getTask(id);
    if (task == null) throw const ValidationException('Задача не найдена');
    return task;
  }

  // ---------------- создание/изменение ----------------

  /// Создание задачи и первая запись истории выполняются в одной транзакции.
  @override
  Future<int> createTask({
    required String title,
    required String description,
    required int projectId,
    int? assigneeId,
    required TaskPriority priority,
    required TaskStatus status,
    DateTime? deadline,
    int? actorId,
  }) {
    return _db.transaction(() async {
      final project = await (_db.select(
        _db.projects,
      )..where((p) => p.id.equals(projectId))).getSingleOrNull();
      if (project == null) {
        throw const ValidationException(
          'Задача должна принадлежать существующему проекту',
        );
      }
      if (assigneeId != null) {
        await _assertMember(projectId, assigneeId);
        await _assertWorkload(assigneeId, deadline);
      }
      final now = DateTime.now();
      final id = await _db
          .into(_db.tasks)
          .insert(
            TasksCompanion.insert(
              title: title,
              description: Value(description),
              projectId: projectId,
              assigneeId: Value(assigneeId),
              priority: Value(priority),
              status: Value(status),
              deadline: Value(deadline),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _addHistory(
        taskId: id,
        kind: HistoryKind.created,
        newStatus: status,
        actorId: actorId,
        note: 'Задача создана',
      );
      return id;
    });
  }

  @override
  Future<void> updateTask(
    int id, {
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) {
    return _db.transaction(() async {
      final task = await _require(id);
      if (deadline != null &&
          task.assigneeId != null &&
          task.status.isUnfinished) {
        await _assertWorkload(task.assigneeId, deadline, excludeTaskId: id);
      }
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          title: Value(title),
          description: Value(description),
          priority: Value(priority),
          deadline: Value(deadline),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  @override
  Future<void> changePriority(int id, TaskPriority priority) async {
    await _require(id);
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        priority: Value(priority),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Смена статуса + запись в историю (атомарно).
  @override
  Future<void> changeStatus(int id, TaskStatus newStatus, {int? actorId}) {
    return _db.transaction(() async {
      final task = await _require(id);
      if (task.status == newStatus) return;
      if (newStatus.isUnfinished && !task.status.isUnfinished) {
        // Возврат в работу — проверяем лимит исполнителя.
        await _assertWorkload(
          task.assigneeId,
          task.deadline,
          excludeTaskId: id,
        );
      }
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _addHistory(
        taskId: id,
        kind: HistoryKind.status,
        oldStatus: task.status,
        newStatus: newStatus,
        actorId: actorId,
      );
    });
  }

  /// Назначение / переназначение: проверка участия в проекте, лимита,
  /// обновление задачи и запись события в историю — одной транзакцией.
  @override
  Future<void> assignTask(int id, int? assigneeId, {int? actorId}) {
    return _db.transaction(() async {
      final task = await _require(id);
      if (task.assigneeId == assigneeId) return;
      String? newName;
      if (assigneeId != null) {
        await _assertMember(task.projectId, assigneeId);
        if (task.status.isUnfinished) {
          await _assertWorkload(assigneeId, task.deadline, excludeTaskId: id);
        }
        newName = (await (_db.select(
          _db.users,
        )..where((u) => u.id.equals(assigneeId))).getSingle()).name;
      }
      String? oldName;
      if (task.assigneeId != null) {
        oldName =
            (await (_db.select(_db.users)
                      ..where((u) => u.id.equals(task.assigneeId!)))
                    .getSingleOrNull())
                ?.name;
      }
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          assigneeId: Value(assigneeId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _addHistory(
        taskId: id,
        kind: HistoryKind.assignee,
        oldStatus: task.status,
        newStatus: task.status,
        actorId: actorId,
        note: 'Исполнитель: ${oldName ?? '—'} → ${newName ?? '—'}',
      );
    });
  }

  // ---------------- Undo ----------------

  /// Возвращает предыдущий статус и фиксирует это в истории (история не стирается).
  @override
  Future<void> undoLastStatusChange(int taskId, {int? actorId}) {
    return _db.transaction(() async {
      final task = await _require(taskId);
      final last = await _lastUndoableQuery(taskId).getSingleOrNull();
      if (last == null || last.oldStatus == null) {
        throw const ValidationException('Нет изменений статуса для отмены');
      }
      await (_db.update(_db.taskHistory)..where((h) => h.id.equals(last.id)))
          .write(const TaskHistoryCompanion(undone: Value(true)));
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(last.oldStatus!),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _addHistory(
        taskId: taskId,
        kind: HistoryKind.undo,
        oldStatus: task.status,
        newStatus: last.oldStatus!,
        actorId: actorId,
        note: 'Отмена изменения статуса',
      );
    });
  }

  // ---------------- корзина (soft delete) ----------------

  @override
  Future<void> softDelete(int id) async {
    await _require(id);
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> restore(int id) {
    return _db.transaction(() async {
      final task = await _require(id);
      if (task.status.isUnfinished) {
        await _assertWorkload(
          task.assigneeId,
          task.deadline,
          excludeTaskId: id,
        );
      }
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Физическое удаление (только из корзины).
  @override
  Future<void> deleteForever(int id) async {
    final task = await _require(id);
    if (task.deletedAt == null) {
      throw const ValidationException('Сначала переместите задачу в корзину');
    }
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }
}
