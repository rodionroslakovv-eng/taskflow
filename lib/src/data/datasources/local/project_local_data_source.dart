import 'package:drift/drift.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../models/app_database.dart';
import '../../../../models/relation_models.dart';
import '../../../domain/entities/enums.dart';
import 'db_utils.dart';

abstract class ProjectLocalDataSource {
  Stream<List<ProjectRow>> watchProjects();
  Future<List<ProjectRow>> getProjects();
  Future<ProjectRow?> getProject(int id);
  Stream<ProjectRow?> watchProject(int id);

  Future<int> createProject({
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
    int? ownerId,
  });

  Future<void> updateProject(
    int id, {
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  });

  Future<void> deleteProject(int id);

  Stream<List<MemberModel>> watchMembers(int projectId);
  Future<List<MemberModel>> getMembers(int projectId);

  Future<void> addMember({
    required int projectId,
    required int userId,
    required MemberRole role,
  });

  Future<void> removeMember(int projectId, int userId);
  Future<void> setRole(int projectId, int userId, MemberRole role);
}

class ProjectLocalDataSourceImpl implements ProjectLocalDataSource {
  ProjectLocalDataSourceImpl(this._db);
  final AppDatabase _db;

  @override
  Stream<List<ProjectRow>> watchProjects() => (_db.select(
    _db.projects,
  )..orderBy([(p) => OrderingTerm.desc(p.createdAt)])).watch();

  @override
  Future<List<ProjectRow>> getProjects() => (_db.select(
    _db.projects,
  )..orderBy([(p) => OrderingTerm.asc(p.name)])).get();

  @override
  Future<ProjectRow?> getProject(int id) => (_db.select(
    _db.projects,
  )..where((p) => p.id.equals(id))).getSingleOrNull();

  @override
  Stream<ProjectRow?> watchProject(int id) => (_db.select(
    _db.projects,
  )..where((p) => p.id.equals(id))).watchSingleOrNull();

  @override
  Future<int> createProject({
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
    int? ownerId,
  }) {
    return _db.transaction(() async {
      final id = await _db
          .into(_db.projects)
          .insert(
            ProjectsCompanion.insert(
              name: name,
              description: Value(description),
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

  @override
  Future<void> updateProject(
    int id, {
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) async {
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: Value(name),
        description: Value(description),
        status: Value(status),
        finishedAt: Value(finishedAt),
      ),
    );
  }

  @override
  Future<void> deleteProject(int id) async {
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
  }

  // ---------------- участники ----------------

  JoinedSelectStatement<HasResultSet, dynamic> _membersQuery(int projectId) {
    final m = _db.projectMembers;
    final u = _db.users;
    return _db.select(m).join([innerJoin(u, u.id.equalsExp(m.userId))])
      ..where(m.projectId.equals(projectId))
      ..orderBy([OrderingTerm.asc(u.name)]);
  }

  MemberModel _mapMember(TypedResult r) => MemberModel(
    member: r.readTable(_db.projectMembers),
    user: r.readTable(_db.users),
  );

  @override
  Stream<List<MemberModel>> watchMembers(int projectId) =>
      _membersQuery(projectId).map(_mapMember).watch();

  @override
  Future<List<MemberModel>> getMembers(int projectId) =>
      _membersQuery(projectId).map(_mapMember).get();

  Future<bool> _isMember(int projectId, int userId) async {
    final m = _db.projectMembers;
    final row =
        await (_db.select(m)..where(
              (x) => x.projectId.equals(projectId) & x.userId.equals(userId),
            ))
            .getSingleOrNull();
    return row != null;
  }

  @override
  Future<void> addMember({
    required int projectId,
    required int userId,
    required MemberRole role,
  }) {
    return _db.transaction(() async {
      if (await getProject(projectId) == null) {
        throw const ValidationException('Проект не найден');
      }
      final user = await (_db.select(
        _db.users,
      )..where((u) => u.id.equals(userId))).getSingleOrNull();
      if (user == null) throw const ValidationException('Пользователь не найден');
      if (await _isMember(projectId, userId)) {
        throw const ValidationException('Пользователь уже состоит в этом проекте');
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
          throw const ValidationException(
            'Пользователь уже состоит в этом проекте',
          );
        }
        rethrow;
      }
    });
  }

  @override
  Future<void> removeMember(int projectId, int userId) {
    return _db.transaction(() async {
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

  @override
  Future<void> setRole(int projectId, int userId, MemberRole role) async {
    await (_db.update(_db.projectMembers)..where(
          (m) => m.projectId.equals(projectId) & m.userId.equals(userId),
        ))
        .write(ProjectMembersCompanion(role: Value(role)));
  }
}
