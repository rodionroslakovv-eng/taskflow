import 'package:drift/drift.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../models/app_database.dart';
import '../../../domain/entities/enums.dart';
import 'db_utils.dart';

abstract class UserLocalDataSource {
  Stream<List<UserRow>> watchUsers();
  Future<List<UserRow>> getUsers();
  Stream<UserRow?> watchUser(int id);
  Future<int> createUser({
    required String name,
    required String email,
    DateTime? registeredAt,
  });
  Future<void> updateUser(int id, {required String name, required String email});
  Future<void> deleteUser(int id);
}

class UserLocalDataSourceImpl implements UserLocalDataSource {
  UserLocalDataSourceImpl(this._db);
  final AppDatabase _db;

  @override
  Stream<List<UserRow>> watchUsers() => (_db.select(
    _db.users,
  )..orderBy([(u) => OrderingTerm.asc(u.name)])).watch();

  @override
  Future<List<UserRow>> getUsers() =>
      (_db.select(_db.users)..orderBy([(u) => OrderingTerm.asc(u.name)])).get();

  @override
  Stream<UserRow?> watchUser(int id) => (_db.select(
    _db.users,
  )..where((u) => u.id.equals(id))).watchSingleOrNull();

  Future<void> _assertEmailFree(String email, {int? exceptId}) async {
    final q = _db.select(_db.users)..where((u) => u.email.equals(email));
    if (exceptId != null) q.where((u) => u.id.equals(exceptId).not());
    if (await q.getSingleOrNull() != null) {
      throw const ValidationException(
        'Пользователь с таким email уже существует',
      );
    }
  }

  @override
  Future<int> createUser({
    required String name,
    required String email,
    DateTime? registeredAt,
  }) {
    return _db.transaction(() async {
      await _assertEmailFree(email);
      try {
        return await _db
            .into(_db.users)
            .insert(
              UsersCompanion.insert(
                name: name,
                email: email,
                registeredAt: Value(registeredAt ?? DateTime.now()),
              ),
            );
      } catch (err) {
        if (isUniqueViolation(err)) {
          throw const ValidationException(
            'Пользователь с таким email уже существует',
          );
        }
        rethrow;
      }
    });
  }

  @override
  Future<void> updateUser(int id, {required String name, required String email}) {
    return _db.transaction(() async {
      await _assertEmailFree(email, exceptId: id);
      await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
        UsersCompanion(name: Value(name), email: Value(email)),
      );
    });
  }

  /// Нельзя удалить пользователя с незавершёнными (todo/inProgress) задачами.
  @override
  Future<void> deleteUser(int id) {
    return _db.transaction(() async {
      final t = _db.tasks;
      final cnt = t.id.count();
      final q = _db.selectOnly(t)
        ..addColumns([cnt])
        ..where(
          t.assigneeId.equals(id) &
              t.deletedAt.isNull() &
              t.status.isInValues([TaskStatus.todo, TaskStatus.inProgress]),
        );
      final active = await q.map((r) => r.read(cnt)!).getSingle();
      if (active > 0) {
        throw ValidationException(
          'Нельзя удалить: за пользователем закреплено незавершённых задач: $active',
        );
      }
      await (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();
    });
  }
}
