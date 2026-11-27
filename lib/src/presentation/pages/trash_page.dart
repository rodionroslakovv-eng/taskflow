import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../core/di/injection_container.dart';
import '../../domain/entities/task.dart';
import '../bloc/tasks/task_cubits.dart';
import '../widgets/run_action.dart';
import '../widgets/task_tile.dart';
import '../widgets/view_state_builder.dart';
import 'task_detail_page.dart';

/// Корзина: задачи с заполненным deletedAt.
class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TrashCubit>(
      create: (_) => getIt<TrashCubit>()..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Корзина')),
        body: ViewStateBuilder<TrashCubit, List<TaskItem>>(
          emptyText: 'Корзина пуста',
          builder: (context, items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              final cubit = context.read<TrashCubit>();
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
                          builder: (_) => TaskDetailPage(taskId: it.task.id),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Восстановить',
                      icon: const Icon(Icons.restore_from_trash),
                      onPressed: () =>
                          runAction(context, cubit.restore(it.task.id)),
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
                          await runAction(
                            context,
                            cubit.deleteForever(it.task.id),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
