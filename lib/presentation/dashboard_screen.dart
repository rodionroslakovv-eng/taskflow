import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import 'widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return StreamBuilder<DashboardStats>(
      stream: repos.stats.watchStats(),
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) return const Center(child: CircularProgressIndicator());
        final maxPriority = s.byPriority.fold<int>(
          1,
          (m, e) => e.count > m ? e.count : m,
        );
        final maxAssignee = s.byAssignee.fold<int>(
          1,
          (m, e) => e.count > m ? e.count : m,
        );
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _stat('Проекты', s.projects, Icons.folder, Colors.indigo),
                _stat(
                  'Всего задач',
                  s.totalTasks,
                  Icons.list_alt,
                  Colors.blueGrey,
                ),
                _stat(
                  'Завершено',
                  s.doneTasks,
                  Icons.check_circle,
                  Colors.green,
                ),
                _stat(
                  'Не завершено',
                  s.unfinishedTasks,
                  Icons.timelapse,
                  Colors.orange,
                ),
                _stat(
                  'Просрочено',
                  s.overdueTasks,
                  Icons.warning_amber,
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _title('Задачи по приоритетам'),
            for (final e in s.byPriority)
              _bar(
                e.priority.label,
                e.count,
                e.count / maxPriority,
                priorityColor(e.priority),
              ),
            if (s.byPriority.isEmpty) const Text('Нет данных'),
            const SizedBox(height: 16),
            _title('Задачи по исполнителям'),
            for (final e in s.byAssignee.take(15))
              _bar(e.name, e.count, e.count / maxAssignee, Colors.teal),
            if (s.byAssignee.isEmpty) const Text('Нет данных'),
            if (s.byAssignee.length > 15)
              Text(
                '… и ещё ${s.byAssignee.length - 15} исполнителей',
                style: const TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 16),
            _title('Выполнение проектов'),
            for (final p in s.projectProgress)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          '${p.percent.toStringAsFixed(0)}%  (${p.done}/${p.total})',
                        ),
                      ],
                    ),
                    LinearProgressIndicator(value: p.percent / 100),
                  ],
                ),
              ),
            if (s.projectProgress.isEmpty) const Text('Нет проектов'),
          ],
        );
      },
    );
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );

  Widget _stat(String label, int value, IconData icon, Color color) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  key: Key('stat_$label'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bar(String label, int count, double fraction, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: fraction,
            color: color,
            minHeight: 10,
          ),
        ),
        SizedBox(width: 40, child: Text('$count', textAlign: TextAlign.end)),
      ],
    ),
  );
}
