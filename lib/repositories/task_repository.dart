import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';

/// Максимум незавершённых задач у исполнителя на один дедлайн (день).
const int kMaxTasksPerDeadline = 3;

class TaskRepository {
  TaskRepository(this._db);
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

  TaskItem _map(TypedResult r) => TaskItem(
    task: r.readTable(_db.tasks),
    assignee: r.readTableOrNull(_db.users),
    project: r.readTable(_db.projects),
  );

  Stream<List<TaskItem>> watchTasks(TaskFilter f) =>
      _query(f).map(_map).watch();

  Future<List<TaskItem>> getTasks(TaskFilter f) => _query(f).map(_map).get();

  Future<int> countTasks(TaskFilter f) async {
    final all = await getTasks(f.copyWith(limit: null, offset: 0));
    return all.length;
  }

  Stream<TaskItem?> watchTask(int id) {
    final t = _db.tasks;
    final u = _db.users;
    final p = _db.projects;
    final q = _db.select(t).join([
      leftOuterJoin(u, u.id.equalsExp(t.assigneeId)),
      innerJoin(p, p.id.equalsExp(t.projectId)),
    ])..where(t.id.equals(id));
    return q.map(_map).watchSingleOrNull();
  }

  Future<TaskRow?> getTask(int id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<HistoryItem>> watchHistory(int taskId) {
    final h = _db.taskHistory;
    final u = _db.users;
    final q =
        _db.select(h).join([leftOuterJoin(u, u.id.equalsExp(h.changedBy))])
          ..where(h.taskId.equals(taskId))
          ..orderBy([OrderingTerm.desc(h.id)]);
    return q
        .map(
          (r) => HistoryItem(entry: r.readTable(h), user: r.readTableOrNull(u)),
        )
        .watch();
  }

  Future<List<HistoryRow>> getHistory(int taskId) =>
      (_db.select(_db.taskHistory)
            ..where((h) => h.taskId.equals(taskId))
            ..orderBy([(h) => OrderingTerm.asc(h.id)]))
          .get();

  // ---------------- проверки ----------------

  Future<void> _assertMember(int projectId, int userId) async {
    final m = _db.projectMembers;
    final row =
        await (_db.select(m)..where(
              (x) => x.projectId.equals(projectId) & x.userId.equals(userId),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw TaskFlowException('Исполнитель не состоит в проекте задачи');
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
      throw TaskFlowException(
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

  // ---------------- создание/изменение ----------------

  /// Создание задачи и первая запись истории выполняются в одной транзакции.
  Future<int> createTask({
    required String title,
    String description = '',
    required int projectId,
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? deadline,
    int? actorId,
  }) async {
    final ttl = title.trim();
    if (ttl.isEmpty)
      throw TaskFlowException('Название задачи не может быть пустым');
    return _db.transaction(() async {
      final project = await (_db.select(
        _db.projects,
      )..where((p) => p.id.equals(projectId))).getSingleOrNull();
      if (project == null) {
        throw TaskFlowException(
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
              title: ttl,
              description: Value(description.trim()),
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

  Future<void> updateTask(
    int id, {
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) async {
    final ttl = title.trim();
    if (ttl.isEmpty)
      throw TaskFlowException('Название задачи не может быть пустым');
    await _db.transaction(() async {
      final task = await _require(id);
      if (deadline != null &&
          task.assigneeId != null &&
          task.status.isUnfinished) {
        await _assertWorkload(task.assigneeId, deadline, excludeTaskId: id);
      }
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(
          title: Value(ttl),
          description: Value(description.trim()),
          priority: Value(priority),
          deadline: Value(deadline),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<TaskRow> _require(int id) async {
    final task = await getTask(id);
    if (task == null) throw TaskFlowException('Задача не найдена');
    return task;
  }

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
  Future<void> changeStatus(
    int id,
    TaskStatus newStatus, {
    int? actorId,
  }) async {
    await _db.transaction(() async {
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
  Future<void> assignTask(int id, int? assigneeId, {int? actorId}) async {
    await _db.transaction(() async {
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

  /// Последняя запись истории, которую можно отменить (смена статуса).
  Future<HistoryRow?> lastUndoable(int taskId) {
    final h = _db.taskHistory;
    return (_db.select(h)
          ..where(
            (x) =>
                x.taskId.equals(taskId) &
                x.kind.equalsValue(HistoryKind.status) &
                x.undone.equals(false),
          )
          ..orderBy([(x) => OrderingTerm.desc(x.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<HistoryRow?> watchLastUndoable(int taskId) {
    final h = _db.taskHistory;
    return (_db.select(h)
          ..where(
            (x) =>
                x.taskId.equals(taskId) &
                x.kind.equalsValue(HistoryKind.status) &
                x.undone.equals(false),
          )
          ..orderBy([(x) => OrderingTerm.desc(x.id)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Возвращает предыдущий статус и фиксирует это в истории (история не стирается).
  Future<void> undoLastStatusChange(int taskId, {int? actorId}) async {
    await _db.transaction(() async {
      final task = await _require(taskId);
      final last = await lastUndoable(taskId);
      if (last == null || last.oldStatus == null) {
        throw TaskFlowException('Нет изменений статуса для отмены');
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

  Future<void> softDelete(int id) async {
    await _require(id);
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> restore(int id) async {
    await _db.transaction(() async {
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
  Future<void> deleteForever(int id) async {
    final task = await _require(id);
    if (task.deletedAt == null) {
      throw TaskFlowException('Сначала переместите задачу в корзину');
    }
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }
}
