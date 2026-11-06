import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/models/models.dart';
import 'package:taskflow/repositories/performance_service.dart';
import 'package:taskflow/repositories/task_repository.dart';

void main() {
  test('1000 пользователей / 100 проектов / 10 000 задач: пагинация и индексы', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final svc = PerformanceService(db);
    await svc.seed();

    expect((await db.select(db.users).get()).length, 1000);
    expect((await db.select(db.projects).get()).length, 100);
    expect((await db.select(db.tasks).get()).length, 10000);

    // пагинация: страницы не пересекаются
    final repo = TaskRepository(db);
    final p1 = await repo.getTasks(const TaskFilter(limit: 50));
    final p2 = await repo.getTasks(const TaskFilter(limit: 50, offset: 50));
    expect(p1, hasLength(50));
    expect(p2, hasLength(50));
    expect(
      p1
          .map((e) => e.task.id)
          .toSet()
          .intersection(p2.map((e) => e.task.id).toSet()),
      isEmpty,
    );

    final results = await svc.benchmark(repeats: 5);
    expect(results, hasLength(5));
    // ignore: avoid_print
    for (final r in results) {
      // ignore: avoid_print
      print(
        '${r.name}: с индексами ${r.withIndexMs.toStringAsFixed(2)} мс, '
        'без ${r.withoutIndexMs.toStringAsFixed(2)} мс (×${r.speedup.toStringAsFixed(1)})',
      );
    }

    // индексы после бенчмарка восстановлены
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'",
        )
        .get();
    expect(idx.length, greaterThanOrEqualTo(7));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
