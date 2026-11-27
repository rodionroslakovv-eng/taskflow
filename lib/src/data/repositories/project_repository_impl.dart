import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/local/project_local_data_source.dart';
import '../mapper/mappers.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl(this._local);
  final ProjectLocalDataSource _local;

  @override
  Stream<Either<Failure, List<Project>>> watchProjects() => guardStream(
    _local.watchProjects().map((rows) => rows.map((r) => r.toEntity()).toList()),
  );

  @override
  Future<Either<Failure, List<Project>>> getProjects() => guardCall(() async {
    final rows = await _local.getProjects();
    return rows.map((r) => r.toEntity()).toList();
  });

  @override
  Stream<Either<Failure, Project?>> watchProject(int id) =>
      guardStream(_local.watchProject(id).map((row) => row?.toEntity()));

  @override
  Future<Either<Failure, int>> createProject({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? finishedAt,
    int? ownerId,
  }) => guardCall(
    () => _local.createProject(
      name: name,
      description: description,
      status: status,
      finishedAt: finishedAt,
      ownerId: ownerId,
    ),
  );

  @override
  Future<Either<Failure, Unit>> updateProject(
    int id, {
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) => guardCall(() async {
    await _local.updateProject(
      id,
      name: name,
      description: description,
      status: status,
      finishedAt: finishedAt,
    );
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> deleteProject(int id) => guardCall(() async {
    await _local.deleteProject(id);
    return unit;
  });

  @override
  Stream<Either<Failure, List<ProjectMember>>> watchMembers(int projectId) =>
      guardStream(
        _local
            .watchMembers(projectId)
            .map((rows) => rows.map((r) => r.toEntity()).toList()),
      );

  @override
  Future<Either<Failure, List<ProjectMember>>> getMembers(int projectId) =>
      guardCall(() async {
        final rows = await _local.getMembers(projectId);
        return rows.map((r) => r.toEntity()).toList();
      });

  @override
  Future<Either<Failure, Unit>> addMember({
    required int projectId,
    required int userId,
    MemberRole role = MemberRole.member,
  }) => guardCall(() async {
    await _local.addMember(projectId: projectId, userId: userId, role: role);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> removeMember(int projectId, int userId) =>
      guardCall(() async {
        await _local.removeMember(projectId, userId);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> setMemberRole(
    int projectId,
    int userId,
    MemberRole role,
  ) => guardCall(() async {
    await _local.setRole(projectId, userId, role);
    return unit;
  });
}
