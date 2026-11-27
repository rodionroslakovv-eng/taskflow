import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/enums.dart';
import '../entities/project.dart';

abstract class ProjectRepository {
  Stream<Either<Failure, List<Project>>> watchProjects();
  Future<Either<Failure, List<Project>>> getProjects();
  Stream<Either<Failure, Project?>> watchProject(int id);

  Future<Either<Failure, int>> createProject({
    required String name,
    String description = '',
    ProjectStatus status = ProjectStatus.active,
    DateTime? finishedAt,
    int? ownerId,
  });

  Future<Either<Failure, Unit>> updateProject(
    int id, {
    required String name,
    required String description,
    required ProjectStatus status,
    DateTime? finishedAt,
  });

  Future<Either<Failure, Unit>> deleteProject(int id);

  Stream<Either<Failure, List<ProjectMember>>> watchMembers(int projectId);
  Future<Either<Failure, List<ProjectMember>>> getMembers(int projectId);

  Future<Either<Failure, Unit>> addMember({
    required int projectId,
    required int userId,
    MemberRole role = MemberRole.member,
  });

  Future<Either<Failure, Unit>> removeMember(int projectId, int userId);
  Future<Either<Failure, Unit>> setMemberRole(
    int projectId,
    int userId,
    MemberRole role,
  );
}
