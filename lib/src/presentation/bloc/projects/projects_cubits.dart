import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/project_usecases.dart';
import '../common/watch_cubit.dart';

class ProjectsCubit extends WatchCubit<List<Project>> {
  ProjectsCubit(this._watchProjects, this._createProject);

  final WatchProjectsUseCase _watchProjects;
  final CreateProjectUseCase _createProject;

  @override
  Stream<Either<Failure, List<Project>>> watch() => _watchProjects();

  Future<Either<Failure, Unit>> create({
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
    int? ownerId,
  }) async => (await _createProject(
    name: name,
    description: description,
    status: status,
    finishedAt: finishedAt,
    ownerId: ownerId,
  )).map((_) => unit);
}

class ProjectDetailCubit extends WatchCubit<Project?> {
  ProjectDetailCubit(
    this.projectId,
    this._watchProject,
    this._updateProject,
    this._deleteProject,
  );

  final int projectId;
  final WatchProjectUseCase _watchProject;
  final UpdateProjectUseCase _updateProject;
  final DeleteProjectUseCase _deleteProject;

  @override
  Stream<Either<Failure, Project?>> watch() => _watchProject(projectId);

  Future<Either<Failure, Unit>> update({
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) => _updateProject(
    projectId,
    name: name,
    description: description,
    status: status,
    finishedAt: finishedAt,
  );

  Future<Either<Failure, Unit>> delete() => _deleteProject(projectId);
}

class ProjectMembersCubit extends WatchCubit<List<ProjectMember>> {
  ProjectMembersCubit(
    this.projectId,
    this._watchMembers,
    this._getAddableUsers,
    this._addMember,
    this._removeMember,
    this._setRole,
  );

  final int projectId;
  final WatchProjectMembersUseCase _watchMembers;
  final GetAddableUsersUseCase _getAddableUsers;
  final AddProjectMemberUseCase _addMember;
  final RemoveProjectMemberUseCase _removeMember;
  final SetMemberRoleUseCase _setRole;

  @override
  Stream<Either<Failure, List<ProjectMember>>> watch() =>
      _watchMembers(projectId);

  Future<Either<Failure, List<User>>> addableUsers() =>
      _getAddableUsers(projectId);

  Future<Either<Failure, Unit>> add(int userId, MemberRole role) =>
      _addMember(projectId: projectId, userId: userId, role: role);

  Future<Either<Failure, Unit>> remove(int userId) =>
      _removeMember(projectId, userId);

  Future<Either<Failure, Unit>> setRole(int userId, MemberRole role) =>
      _setRole(projectId, userId, role);
}
