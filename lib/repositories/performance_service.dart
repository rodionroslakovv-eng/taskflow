import 'dart:math';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import 'stats_repository.dart';
import 'task_repository.dart';

class BenchmarkResult {
  const BenchmarkResult(this.name, this.withIndexMs, this.withoutIndexMs);
  final String name;
  final double withIndexMs;
  final double withoutIndexMs;

  double get speedup => withIndexMs == 0 ? 0 : withoutIndexMs / withIndexMs;
}

/// Генерация тестовых данных и сравнение скорости запросов с индексами и без.
class PerformanceService {
  PerformanceService(this._db);
  final AppDatabase _db;

  /// 1000 пользователей, 100 проектов, 10 000 задач (по умолчанию).
  Future<void> seed({
    int users = 1000,
    int projects = 100,
    int tasks = 10000,
    int membersPerProject = 30,
    int seedValue = 42,
  }) async {
    final rnd = Random(seedValue);
    final now = DateTime.now();

    await _db.batch((b) {
      b.insertAll(_db.users, [
        for (var i = 0; i < users; i++)
          UsersCompanion.insert(
            name: 'User $i',
            email: 'seed_user_$i@example.com',
            registeredAt: Value(now.subtract(Duration(days: rnd.nextInt(700)))),
          ),
      ]);
    });
    final userIds = (await _db.select(_db.users).get())
        .map((u) => u.id)
        .toList();

    await _db.batch((b) {
      b.insertAll(_db.projects, [
        for (var i = 0; i < projects; i++)
          ProjectsCompanion.insert(
            name: 'Project $i',
            description: Value('Description of project $i'),
            createdAt: Value(now.subtract(Duration(days: rnd.nextInt(365)))),
          ),
      ]);
    });
    final projectIds = (await _db.select(_db.projects).get())
        .map((p) => p.id)
        .toList();

    final membersByProject = <int, List<int>>{};
    await _db.batch((b) {
      for (final pid in projectIds) {
        final shuffled = [...userIds]..shuffle(rnd);
        final chosen = shuffled
            .take(min(membersPerProject, userIds.length))
            .toList();
        membersByProject[pid] = chosen;
        b.insertAll(_db.projectMembers, [
          for (var i = 0; i < chosen.length; i++)
            ProjectMembersCompanion.insert(
              projectId: pid,
              userId: chosen[i],
              role: i == 0 ? MemberRole.owner : MemberRole.member,
            ),
        ]);
      }
    });

    await _db.batch((b) {
      b.insertAll(_db.tasks, [
        for (var i = 0; i < tasks; i++)
          () {
            final pid = projectIds[rnd.nextInt(projectIds.length)];
            final members = membersByProject[pid]!;
            final created = now.subtract(
              Duration(hours: rnd.nextInt(24 * 200)),
            );
            return TasksCompanion.insert(
              title: 'Task $i',
              description: Value('Generated task number $i'),
              projectId: pid,
              assigneeId: Value(members[rnd.nextInt(members.length)]),
              priority: Value(TaskPriority.values[rnd.nextInt(4)]),
              status: Value(TaskStatus.values[rnd.nextInt(4)]),
              deadline: Value(now.add(Duration(days: rnd.nextInt(120) - 30))),
              createdAt: Value(created),
              updatedAt: Value(created),
            );
          }(),
      ]);
    });
  }

  List<Index> get _indexes => _db.allSchemaEntities.whereType<Index>().toList();

  Future<void> dropIndexes() async {
    for (final i in _indexes) {
      await _db.customStatement('DROP INDEX IF EXISTS ${i.entityName}');
    }
  }

  Future<void> createIndexes() async {
    for (final i in _indexes) {
      await _db.customStatement('DROP INDEX IF EXISTS ${i.entityName}');
      await _db.customStatement(
        (i.createStatementsByDialect[SqlDialect.sqlite] ??
            i.createStatementsByDialect.values.first),
      );
    }
  }

  Future<double> _time(Future<void> Function() body, int repeats) async {
    await body(); // прогрев
    final sw = Stopwatch()..start();
    for (var i = 0; i < repeats; i++) {
      await body();
    }
    sw.stop();
    return sw.elapsedMicroseconds / repeats / 1000.0;
  }

  Future<List<BenchmarkResult>> benchmark({int repeats = 20}) async {
    final tasks = TaskRepository(_db);
    final stats = StatsRepository(_db);
    final someUser = (await (_db.select(_db.users)..limit(1)).getSingle()).id;
    final someProject = (await (_db.select(
      _db.projects,
    )..limit(1)).getSingle()).id;

    final cases = <String, Future<void> Function()>{
      'Задачи исполнителя, сорт. по дедлайну': () async {
        await tasks.getTasks(
          TaskFilter(
            assigneeId: someUser,
            sort: TaskSort.deadline,
            ascending: true,
            limit: 50,
          ),
        );
      },
      'Проект + статус + приоритет': () async {
        await tasks.getTasks(
          TaskFilter(
            projectId: someProject,
            status: TaskStatus.inProgress,
            priority: TaskPriority.high,
            limit: 50,
          ),
        );
      },
      'Страница 50 задач по дате создания': () async {
        await tasks.getTasks(const TaskFilter(limit: 50, offset: 5000));
      },
      'Поиск по названию (LIKE)': () async {
        await tasks.getTasks(const TaskFilter(query: 'Task 77', limit: 50));
      },
      'Статистика Dashboard': () async {
        await stats.getStats();
      },
    };

    final withIdx = <String, double>{};
    final withoutIdx = <String, double>{};

    await createIndexes();
    for (final e in cases.entries) {
      withIdx[e.key] = await _time(e.value, repeats);
    }
    await dropIndexes();
    try {
      for (final e in cases.entries) {
        withoutIdx[e.key] = await _time(e.value, repeats);
      }
    } finally {
      await createIndexes();
    }

    return [
      for (final k in cases.keys)
        BenchmarkResult(k, withIdx[k]!, withoutIdx[k]!),
    ];
  }
}
