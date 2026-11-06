import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';

bool isUniqueViolation(Object e) => e.toString().contains('UNIQUE');

final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class UserRepository {
  UserRepository(this._db);
  final AppDatabase _db;

  Stream<List<UserRow>> watchUsers() => (_db.select(
    _db.users,
  )..orderBy([(u) => OrderingTerm.asc(u.name)])).watch();

  Future<List<UserRow>> getUsers() =>
      (_db.select(_db.users)..orderBy([(u) => OrderingTerm.asc(u.name)])).get();

  Future<UserRow?> getUser(int id) =>
      (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Stream<UserRow?> watchUser(int id) => (_db.select(
    _db.users,
  )..where((u) => u.id.equals(id))).watchSingleOrNull();

  String _checkName(String name) {
    final n = name.trim();
    if (n.isEmpty) throw TaskFlowException('Имя не может быть пустым');
    if (n.length > 100) throw TaskFlowException('Имя слишком длинное');
    return n;
  }

  String _checkEmail(String email) {
    final e = email.trim().toLowerCase();
    if (!_emailRe.hasMatch(e)) throw TaskFlowException('Некорректный email');
    return e;
  }

  Future<void> _assertEmailFree(String email, {int? exceptId}) async {
    final q = _db.select(_db.users)..where((u) => u.email.equals(email));
    if (exceptId != null) q.where((u) => u.id.equals(exceptId).not());
    if (await q.getSingleOrNull() != null) {
      throw TaskFlowException('Пользователь с таким email уже существует');
    }
  }

  Future<int> createUser({
    required String name,
    required String email,
    DateTime? registeredAt,
  }) async {
    final n = _checkName(name);
    final e = _checkEmail(email);
    return _db.transaction(() async {
      await _assertEmailFree(e);
      try {
        return await _db
            .into(_db.users)
            .insert(
              UsersCompanion.insert(
                name: n,
                email: e,
                registeredAt: Value(registeredAt ?? DateTime.now()),
              ),
            );
      } catch (err) {
        if (isUniqueViolation(err)) {
          throw TaskFlowException('Пользователь с таким email уже существует');
        }
        rethrow;
      }
    });
  }

  Future<void> updateUser(
    int id, {
    required String name,
    required String email,
  }) async {
    final n = _checkName(name);
    final e = _checkEmail(email);
    await _db.transaction(() async {
      await _assertEmailFree(e, exceptId: id);
      await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
        UsersCompanion(name: Value(n), email: Value(e)),
      );
    });
  }

  /// Нельзя удалить пользователя с незавершёнными (todo/inProgress) задачами.
  Future<void> deleteUser(int id) async {
    await _db.transaction(() async {
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
        throw TaskFlowException(
          'Нельзя удалить: за пользователем закреплено незавершённых задач: $active',
        );
      }
      await (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();
    });
  }
}
