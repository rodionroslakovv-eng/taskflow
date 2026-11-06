import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import 'user_repository.dart';

class ProjectRepository {
  ProjectRepository(this._db);
  final AppDatabase _db;

  Stream<List<ProjectRow>> watchProjects() => (_db.select(
    _db.projects,
  )..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).watch();

  Future<List<ProjectRow>> getProjects() => (_db.select(
    _db.projects,
  )..orderBy([(p) => OrderingTerm.asc(p.name)])).get();

  Future<ProjectRow?> getProject(int id) => (_db.select(
    _db.projects,
  )..where((p) => p.id.equals(id))).getSingleOrNull();

  Stream<ProjectRow?> watchProject(int id) => (_db.select(
    _db.projects,
  )..where((p) => p.id.equals(id))).watchSingleOrNull();

  String _checkName(String name) {
    final n = name.trim();
    if (n.isEmpty)
      throw TaskFlowException('Название проекта не может быть пустым');
    return n;
  }

  /// Если указан [ownerId], он автоматически добавляется участником с ролью Owner.
  Future<int> createProject({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? finishedAt,
    int? ownerId,
  }) async {
    final n = _checkName(name);
    return _db.transaction(() async {
      final id = await _db
          .into(_db.projects)
          .insert(
            ProjectsCompanion.insert(
              name: n,
              description: Value(description.trim()),
              status: Value(status),
              finishedAt: Value(finishedAt),
              createdAt: Value(DateTime.now()),
            ),
          );
      if (ownerId != null) {
        await addMember(projectId: id, userId: ownerId, role: MemberRole.owner);
      }
      return id;
    });
  }

  Future<void> updateProject(
    int id, {
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) async {
    final n = _checkName(name);
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(n),
        description: Value(description.trim()),
        status: Value(status),
        finishedAt: Value(finishedAt),
      ),
    );
  }

  /// Каскадно удаляет участников, задачи, комментарии и историю проекта.
  Future<void> deleteProject(int id) =>
      (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();

  // ---------------- участники ----------------

  Stream<List<MemberItem>> watchMembers(int projectId) {
    final m = _db.projectMembers;
    final u = _db.users;
    final q = _db.select(m).join([innerJoin(u, u.id.equalsExp(m.userId))])
      ..where(m.projectId.equals(projectId))
      ..orderBy([OrderingTerm.asc(u.name)]);
    return q
        .map((r) => MemberItem(member: r.readTable(m), user: r.readTable(u)))
        .watch();
  }

  Future<List<MemberItem>> getMembers(int projectId) {
    final m = _db.projectMembers;
    final u = _db.users;
    final q = _db.select(m).join([innerJoin(u, u.id.equalsExp(m.userId))])
      ..where(m.projectId.equals(projectId))
      ..orderBy([OrderingTerm.asc(u.name)]);
    return q
        .map((r) => MemberItem(member: r.readTable(m), user: r.readTable(u)))
        .get();
  }

  Future<bool> isMember(int projectId, int userId) async {
    final m = _db.projectMembers;
    final row =
        await (_db.select(m)..where(
              (x) => x.projectId.equals(projectId) & x.userId.equals(userId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  Future<void> addMember({
    required int projectId,
    required int userId,
    MemberRole role = MemberRole.member,
  }) async {
    await _db.transaction(() async {
      if (await getProject(projectId) == null) {
        throw TaskFlowException('Проект не найден');
      }
      final user = await (_db.select(
        _db.users,
      )..where((u) => u.id.equals(userId))).getSingleOrNull();
      if (user == null) throw TaskFlowException('Пользователь не найден');
      if (await isMember(projectId, userId)) {
        throw TaskFlowException('Пользователь уже состоит в этом проекте');
      }
      try {
        await _db
            .into(_db.projectMembers)
            .insert(
              ProjectMembersCompanion.insert(
                projectId: projectId,
                userId: userId,
                role: role,
              ),
            );
      } catch (e) {
        if (isUniqueViolation(e)) {
          throw TaskFlowException('Пользователь уже состоит в этом проекте');
        }
        rethrow;
      }
    });
  }

  /// Удаляет участника; его задачи в этом проекте остаются без исполнителя.
  Future<void> removeMember(int projectId, int userId) async {
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where(
            (t) => t.projectId.equals(projectId) & t.assigneeId.equals(userId),
          ))
          .write(
            TasksCompanion(
              assigneeId: const Value(null),
              updatedAt: Value(DateTime.now()),
            ),
          );
      await (_db.delete(_db.projectMembers)..where(
            (m) => m.projectId.equals(projectId) & m.userId.equals(userId),
          ))
          .go();
    });
  }

  Future<void> setRole(int projectId, int userId, MemberRole role) =>
      (_db.update(_db.projectMembers)..where(
            (m) => m.projectId.equals(projectId) & m.userId.equals(userId),
          ))
          .write(ProjectMembersCompanion(role: Value(role)));

  /// Проекты, в которых состоит пользователь.
  Future<List<ProjectRow>> projectsOfUser(int userId) {
    final m = _db.projectMembers;
    final p = _db.projects;
    final q = _db.select(p).join([innerJoin(m, m.projectId.equalsExp(p.id))])
      ..where(m.userId.equals(userId));
    return q.map((r) => r.readTable(p)).get();
  }
}
