import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/enums.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'task_detail_screen.dart';
import 'task_list_view.dart';
import 'widgets.dart';

/// Корзина: задачи с заполненным deletedAt.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return Scaffold(
      appBar: AppBar(title: const Text('Корзина')),
      body: StreamBuilder<List<TaskItem>>(
        stream: repos.tasks.watchTasks(
          const TaskFilter(onlyDeleted: true, sort: TaskSort.createdAt),
        ),
        builder: (context, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) return const EmptyState('Корзина пуста');
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return TaskTile(
                item: it,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Просмотр',
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(taskId: it.task.id),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Восстановить',
                      icon: const Icon(Icons.restore_from_trash),
                      onPressed: () =>
                          guard(context, () => repos.tasks.restore(it.task.id)),
                    ),
                    IconButton(
                      tooltip: 'Удалить навсегда',
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () async {
                        if (await confirm(
                              context,
                              'Удалить «${it.task.title}» навсегда? Это действие необратимо.',
                            ) &&
                            context.mounted) {
                          await guard(
                            context,
                            () => repos.tasks.deleteForever(it.task.id),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
