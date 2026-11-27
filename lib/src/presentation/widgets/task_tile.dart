import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../constants/app_colors.dart';
import '../../domain/entities/task.dart';
import '../bloc/favorites/favorites_cubits.dart';
import '../pages/task_detail_page.dart';
import 'run_action.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.item,
    this.showProject = true,
    this.trailing,
  });

  final TaskItem item;
  final bool showProject;

  /// Если задан — заменяет звёздочку «избранное» и отключает переход в карточку.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = item.task;
    return ListTile(
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LabelChip(t.status.label, statusColor(t.status)),
            LabelChip(t.priority.label, priorityColor(t.priority)),
            if (showProject)
              Text(item.project.name, style: const TextStyle(fontSize: 12)),
            Text(
              item.assignee?.name ?? 'Не назначен',
              style: const TextStyle(fontSize: 12),
            ),
            if (t.deadline != null)
              Text(
                'до ${fmtDate(t.deadline!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: item.isOverdue ? Colors.red : null,
                  fontWeight: item.isOverdue ? FontWeight.bold : null,
                ),
              ),
          ],
        ),
      ),
      trailing: trailing ?? FavoriteButton(taskId: t.id),
      onTap: trailing != null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: t.id)),
            ),
    );
  }
}

/// Звёздочка «в избранное». Состояние берётся из [FavoritesCubit].
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FavoritesCubit, FavoritesState, bool>(
      selector: (state) => state.contains(taskId),
      builder: (context, isFavorite) => IconButton(
        key: Key('favorite_$taskId'),
        tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
        icon: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          color: isFavorite ? Colors.amber : null,
        ),
        onPressed: () =>
            runAction(context, context.read<FavoritesCubit>().toggle(taskId)),
      ),
    );
  }
}
