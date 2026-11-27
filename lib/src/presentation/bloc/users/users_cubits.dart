import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/usecases/user_usecases.dart';
import '../common/watch_cubit.dart';

class UsersCubit extends WatchCubit<List<User>> {
  UsersCubit(
    this._watchUsers,
    this._createUser,
    this._updateUser,
    this._deleteUser,
  );

  final WatchUsersUseCase _watchUsers;
  final CreateUserUseCase _createUser;
  final UpdateUserUseCase _updateUser;
  final DeleteUserUseCase _deleteUser;

  @override
  Stream<Either<Failure, List<User>>> watch() => _watchUsers();

  Future<Either<Failure, Unit>> create({
    required String name,
    required String email,
  }) async => (await _createUser(name: name, email: email)).map((_) => unit);

  Future<Either<Failure, Unit>> update(
    int id, {
    required String name,
    required String email,
  }) => _updateUser(id, name: name, email: email);

  Future<Either<Failure, Unit>> delete(int id) => _deleteUser(id);
}

class UserDetailCubit extends WatchCubit<User?> {
  UserDetailCubit(this.userId, this._watchUser, this._updateUser);

  final int userId;
  final WatchUserUseCase _watchUser;
  final UpdateUserUseCase _updateUser;

  @override
  Stream<Either<Failure, User?>> watch() => _watchUser(userId);

  Future<Either<Failure, Unit>> update({
    required String name,
    required String email,
  }) => _updateUser(userId, name: name, email: email);
}

/// «Текущий пользователь»: от его имени пишутся история изменений и комментарии.
class CurrentUserState extends Equatable {
  const CurrentUserState(this.userId);
  final int? userId;

  @override
  List<Object?> get props => [userId];
}

class CurrentUserCubit extends Cubit<CurrentUserState> {
  CurrentUserCubit(WatchUsersUseCase watchUsers)
    : super(const CurrentUserState(null)) {
    _subscription = watchUsers().listen((result) {
      result.fold((_) {}, (users) {
        final ids = users.map((u) => u.id);
        final current = state.userId;
        if (current == null || !ids.contains(current)) {
          emit(CurrentUserState(users.isEmpty ? null : users.first.id));
        }
      });
    });
  }

  StreamSubscription<Either<Failure, List<User>>>? _subscription;

  void select(int? id) => emit(CurrentUserState(id));

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
