import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/user.dart';
import '../repositories/user_repository.dart';
import '../validators/validators.dart';

class WatchUsersUseCase {
  const WatchUsersUseCase(this._repository);
  final UserRepository _repository;

  Stream<Either<Failure, List<User>>> call() => _repository.watchUsers();
}

class GetUsersUseCase {
  const GetUsersUseCase(this._repository);
  final UserRepository _repository;

  Future<Either<Failure, List<User>>> call() => _repository.getUsers();
}

class WatchUserUseCase {
  const WatchUserUseCase(this._repository);
  final UserRepository _repository;

  Stream<Either<Failure, User?>> call(int id) => _repository.watchUser(id);
}

class CreateUserUseCase {
  const CreateUserUseCase(this._repository);
  final UserRepository _repository;

  Future<Either<Failure, int>> call({
    required String name,
    required String email,
  }) async {
    final failure = Validators.userName(name) ?? Validators.email(email);
    if (failure != null) return Left(failure);
    return _repository.createUser(
      name: name.trim(),
      email: email.trim().toLowerCase(),
    );
  }
}

class UpdateUserUseCase {
  const UpdateUserUseCase(this._repository);
  final UserRepository _repository;

  Future<Either<Failure, Unit>> call(
    int id, {
    required String name,
    required String email,
  }) async {
    final failure = Validators.userName(name) ?? Validators.email(email);
    if (failure != null) return Left(failure);
    return _repository.updateUser(
      id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
    );
  }
}

class DeleteUserUseCase {
  const DeleteUserUseCase(this._repository);
  final UserRepository _repository;

  Future<Either<Failure, Unit>> call(int id) => _repository.deleteUser(id);
}
