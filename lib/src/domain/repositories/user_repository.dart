import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/user.dart';

abstract class UserRepository {
  Stream<Either<Failure, List<User>>> watchUsers();
  Future<Either<Failure, List<User>>> getUsers();
  Stream<Either<Failure, User?>> watchUser(int id);

  Future<Either<Failure, int>> createUser({
    required String name,
    required String email,
  });

  Future<Either<Failure, Unit>> updateUser(
    int id, {
    required String name,
    required String email,
  });

  /// Нельзя удалить пользователя с незавершёнными задачами.
  Future<Either<Failure, Unit>> deleteUser(int id);
}
