import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/local/user_local_data_source.dart';
import '../mapper/mappers.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._local);
  final UserLocalDataSource _local;

  @override
  Stream<Either<Failure, List<User>>> watchUsers() => guardStream(
    _local.watchUsers().map((rows) => rows.map((r) => r.toEntity()).toList()),
  );

  @override
  Future<Either<Failure, List<User>>> getUsers() => guardCall(() async {
    final rows = await _local.getUsers();
    return rows.map((r) => r.toEntity()).toList();
  });

  @override
  Stream<Either<Failure, User?>> watchUser(int id) =>
      guardStream(_local.watchUser(id).map((row) => row?.toEntity()));

  @override
  Future<Either<Failure, int>> createUser({
    required String name,
    required String email,
  }) => guardCall(() => _local.createUser(name: name, email: email));

  @override
  Future<Either<Failure, Unit>> updateUser(
    int id, {
    required String name,
    required String email,
  }) => guardCall(() async {
    await _local.updateUser(id, name: name, email: email);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> deleteUser(int id) => guardCall(() async {
    await _local.deleteUser(id);
    return unit;
  });
}
