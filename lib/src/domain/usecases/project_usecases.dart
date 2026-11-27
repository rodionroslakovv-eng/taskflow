import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/enums.dart';
import '../entities/project.dart';
import '../entities/user.dart';
import '../repositories/project_repository.dart';
import '../repositories/user_repository.dart';
import '../validators/validators.dart';

class WatchProjectsUseCase {
  const WatchProjectsUseCase(this._repository);
  final ProjectRepository _repository;

  Stream<Either<Failure, List<Project>>> call() => _repository.watchProjects();
}

class GetProjectsUseCase {
  const GetProjectsUseCase(this._repository);
  final ProjectRepository _repository;

  Future<Either<Failure, List<Project>>> call() => _repository.getProjects();
}

class WatchProjectUseCase {
  const WatchProjectUseCase(this._repository);
  final ProjectRepository _repository;

  Stream<Either<Failure, Project?>> call(int id) =>
      _repository.watchProject(id);
}

class CreateProjectUseCase {
  const CreateProjectUseCase(this._repository);
  final ProjectRepository _repository;

  /// Если указан [ownerId], он автоматически становится участником с ролью Owner.
  Future<Either<Failure, int>> call({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? finishedAt,
    int? ownerId,
  }) async {
    final failure = Validators.projectName(name);
    if (failure != null) return Left(failure);
    return _repository.createProject(
      name: name.trim(),
      description: description.trim(),
      status: status,
      finishedAt: finishedAt,
      ownerId: ownerId,
    );
  }
}

class UpdateProjectUseCase {
  const UpdateProjectUseCase(this._repository);
  final ProjectRepository _repository;

  Future<Either<Failure, Unit>> call(
    int id, {
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  }) async {
    final failure = Validators.projectName(name);
    if (failure != null) return Left(failure);
    return _repository.updateProject(
      id,
      name: name.trim(),
      description: description.trim(),
      status: status,
      finishedAt: finishedAt,
    );
  }
}

/// Каскадно удаляет участников, задачи, комментарии и историю проекта.
class DeleteProjectUseCase {
  const DeleteProjectUseCase(this._repository);
  final ProjectRepository _repository;

  Future<Either<Failure, Unit>> call(int id) => _repository.deleteProject(id);
}

class WatchProjectMembersUseCase {
  const WatchProjectMembersUseCase(this._repository);
  final ProjectRepository _repository;

  Stream<Either<Failure, List<ProjectMember>>> call(int projectId) =>
      _repository.watchMembers(projectId);
}

class GetProjectMembersUseCase {
  const GetProjectMembersUseCase(this._repository);
  final ProjectRepository _repository;

  Future<Either<Failure, List<ProjectMember>>> call(int projectId) =>
      _repository.getMembers(projectId);
}

/// Пользователи, которых ещё можно добавить в проект.
class GetAddableUsersUseCase {
  const GetAddableUsersUseCase(this._projects, this._users);
  final ProjectRepository _projects;
  final UserRepository _users;

  Future<Either<Failure, List<User>>> call(int projectId) async {
    final members = await _projects.getMembers(projectId);
    if (members.isLeft) return Left(members.leftOrNull!);
    final all = await _users.getUsers();
    if (all.isLeft) return Left(all.leftOrNull!);
    final taken = members.rightOrNull!.map((m) => m.user.id).toSet();
    return Right(all.rightOrNull!.where((u) => !taken.contains(u.id)).toList());
  }
}

class AddProjectMemberUseCase {
  const AddProjectMemberUseCase(this._repository);
  final ProjectRepository _repository;

  Future<Either<Failure, Unit>> call({
    required int projectId,
    required int userId,
    MemberRole role = MemberRole.member,
  }) => _repository.addMember(projectId: projectId, userId: userId, role: role);
}

/// Задачи участника в этом проекте остаются без исполнителя.
class RemoveProjectMemberUseCase {
  const RemoveProjectMemberUseCase(this._repository);
  final ProjectRepository _repository;

  Future<Either<Failure, Unit>> call(int projectId, int userId) =>
      _repository.removeMember(projectId, userId);
}

class SetMemberRoleUseCase {
  const SetMemberRoleUseCase(this._repository);
  final ProjectRepository _repository;

  Future<Either<Failure, Unit>> call(
    int projectId,
    int userId,
    MemberRole role,
  ) => _repository.setMemberRole(projectId, userId, role);
}
