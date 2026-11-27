import 'package:drift/drift.dart';

import '../../../../models/app_database.dart';
import '../../../../models/stats_models.dart';

abstract class StatsLocalDataSource {
  Future<DashboardStatsModel> getStats({DateTime? now});
  Stream<DashboardStatsModel> watchStats();
}

/// Вся статистика считается SQL-запросами к SQLite (customSelect).
class StatsLocalDataSourceImpl implements StatsLocalDataSource {
  StatsLocalDataSourceImpl(this._db);
  final AppDatabase _db;

  @override
  Future<DashboardStatsModel> getStats({DateTime? now}) async {
    final moment = now ?? DateTime.now();

    final totals = await _db
        .customSelect(
          '''
      SELECT
        (SELECT COUNT(*) FROM projects) AS projects,
        COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END), 0) AS done,
        COALESCE(SUM(CASE WHEN status IN ('todo','inProgress') THEN 1 ELSE 0 END), 0) AS unfinished,
        COALESCE(SUM(CASE WHEN status IN ('todo','inProgress')
                           AND deadline IS NOT NULL AND deadline < ? THEN 1 ELSE 0 END), 0) AS overdue
      FROM tasks
      WHERE deleted_at IS NULL
      ''',
          variables: [Variable<DateTime>(moment)],
          readsFrom: {_db.tasks, _db.projects},
        )
        .getSingle();

    final byPriority = await _db
        .customSelect(
          '''
      SELECT priority, COUNT(*) AS c
      FROM tasks WHERE deleted_at IS NULL
      GROUP BY priority ORDER BY priority
      ''',
          readsFrom: {_db.tasks},
        )
        .get();

    final byAssignee = await _db
        .customSelect(
          '''
      SELECT u.id AS id, u.name AS name, COUNT(t.id) AS c
      FROM users u
      JOIN tasks t ON t.assignee_id = u.id AND t.deleted_at IS NULL
      GROUP BY u.id, u.name
      ORDER BY c DESC, u.name
      LIMIT 100
      ''',
          readsFrom: {_db.tasks, _db.users},
        )
        .get();

    final progress = await _db
        .customSelect(
          '''
      SELECT p.id AS id, p.name AS name,
             COUNT(t.id) AS total,
             COALESCE(SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END), 0) AS done,
             CASE WHEN COUNT(t.id) = 0 THEN 0.0
                  ELSE 100.0 * SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) / COUNT(t.id)
             END AS percent
      FROM projects p
      LEFT JOIN tasks t ON t.project_id = p.id AND t.deleted_at IS NULL
      GROUP BY p.id, p.name
      ORDER BY p.name
      ''',
          readsFrom: {_db.tasks, _db.projects},
        )
        .get();

    return DashboardStatsModel(
      projects: totals.read<int>('projects'),
      totalTasks: totals.read<int>('total'),
      doneTasks: totals.read<int>('done'),
      unfinishedTasks: totals.read<int>('unfinished'),
      overdueTasks: totals.read<int>('overdue'),
      byPriority: [
        for (final r in byPriority)
          PriorityCountModel(
            r.read<int>('priority'),
            r.read<int>('c'),
          ),
      ],
      byAssignee: [
        for (final r in byAssignee)
          AssigneeCountModel(
            r.read<int>('id'),
            r.read<String>('name'),
            r.read<int>('c'),
          ),
      ],
      projectProgress: [
        for (final r in progress)
          ProjectProgressModel(
            projectId: r.read<int>('id'),
            name: r.read<String>('name'),
            total: r.read<int>('total'),
            done: r.read<int>('done'),
            percent: r.read<double>('percent'),
          ),
      ],
    );
  }

  /// Реактивная статистика: пересчитывается при любом изменении задач/проектов/пользователей.
  @override
  Stream<DashboardStatsModel> watchStats() async* {
    yield await getStats();
    await for (final _ in _db.tableUpdates(
      TableUpdateQuery.onAllTables([_db.tasks, _db.projects, _db.users]),
    )) {
      yield await getStats();
    }
  }
}
