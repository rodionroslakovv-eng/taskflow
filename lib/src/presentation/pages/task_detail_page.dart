import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../core/di/injection_container.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/task.dart';
import '../bloc/common/view_state.dart';
import '../bloc/favorites/favorites_cubits.dart';
import '../bloc/tasks/task_cubits.dart';
import '../bloc/users/users_cubits.dart';
import '../widgets/run_action.dart';
import '../widgets/task_sections.dart';
import 'task_form_page.dart';

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({super.key, required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TaskDetailCubit>(
      create: (_) => getIt<TaskDetailCubit>(param1: taskId)..load(),
      child: BlocBuilder<TaskDetailCubit, ViewState<TaskItem?>>(
        builder: (context, state) => switch (state) {
          ViewSuccess<TaskItem?>(:final data) when data != null => _Content(
            item: data,
          ),
          ViewInitial<TaskItem?>() ||
          ViewLoading<TaskItem?>() => Scaffold(
            appBar: AppBar(),
            body: const LoadingView(),
          ),
          ViewError<TaskItem?>() => Scaffold(
            appBar: AppBar(),
            body: ErrorView(
              message: 'Не удалось загрузить задачу',
              onRetry: context.read<TaskDetailCubit>().retry,
            ),
          ),
          _ => Scaffold(
            appBar: AppBar(),
            body: const EmptyState('Задача не найдена'),
          ),
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.item});
  final TaskItem item;

  @override
  Widget build(BuildContext context) {
    final t = item.task;
    final inTrash = t.isDeleted;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задача'),
        actions: [
          BlocSelector<FavoritesCubit, FavoritesState, bool>(
            selector: (s) => s.contains(t.id),
            builder: (context, isFavorite) => IconButton(
              key: const Key('favoriteToggle'),
              tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : null,
              ),
              onPressed: () => runAction(
                context,
                context.read<FavoritesCubit>().toggle(t.id),
              ),
            ),
          ),
          if (!inTrash)
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TaskFormPage(task: t)),
              ),
            ),
          if (!inTrash)
            IconButton(
              tooltip: 'В корзину',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final nav = Navigator.of(context);
                final ok = await runAction(
                  context,
                  context.read<TaskDetailCubit>().moveToTrash(),
                );
                if (ok != null) nav.pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (inTrash)
            const Card(
              color: Color(0xFFFFF3E0),
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Задача находится в корзине'),
              ),
            ),
          Text(t.title, style: Theme.of(context).textTheme.headlineSmall),
          if (t.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t.description),
          ],
          const SizedBox(height: 12),
          _infoRow('Проект', item.project.name),
          _infoRow('Создана', fmtDateTime(t.createdAt)),
          _infoRow('Изменена', fmtDateTime(t.updatedAt)),
          _infoRow('Дедлайн', t.deadline == null ? '—' : fmtDate(t.deadline!)),
          const Divider(),
          if (!inTrash) _Controls(item: item),
          const Divider(),
          HistorySection(taskId: t.id),
          CommentsSection(taskId: t.id, readOnly: inTrash),
          AttachmentsSection(taskId: t.id, readOnly: inTrash),
        ],
      ),
    );
  }

  Widget _infoRow(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(k, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.item});
  final TaskItem item;

  @override
  Widget build(BuildContext context) {
    final t = item.task;
    final cubit = context.read<TaskDetailCubit>();
    final actor = context.watch<CurrentUserCubit>().state.userId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<TaskStatus>(
          key: const Key('statusDropdown'),
          initialValue: t.status,
          decoration: const InputDecoration(labelText: 'Статус'),
          items: [
            for (final s in TaskStatus.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (s) =>
              runAction(context, cubit.changeStatus(s!, actorId: actor)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TaskPriority>(
          initialValue: t.priority,
          decoration: const InputDecoration(labelText: 'Приоритет'),
          items: [
            for (final pr in TaskPriority.values)
              DropdownMenuItem(value: pr, child: Text(pr.label)),
          ],
          onChanged: (pr) => runAction(context, cubit.changePriority(pr!)),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Исполнитель: ${item.assignee?.name ?? 'не назначен'}'),
          trailing: TextButton(
            onPressed: () => _pickAssignee(context, actor),
            child: const Text('Изменить'),
          ),
        ),
        BlocProvider<LastUndoableCubit>(
          create: (_) => getIt<LastUndoableCubit>(param1: t.id)..load(),
          child: _UndoButton(actorId: actor),
        ),
      ],
    );
  }

  Future<void> _pickAssignee(BuildContext context, int? actor) async {
    final cubit = context.read<TaskDetailCubit>();
    final members = await runAction(
      context,
      cubit.projectMembers(item.project.id),
    );
    if (members == null || !context.mounted) return;
    final res = await showDialog<Object>(
      context: context,
      builder: (dc) => SimpleDialog(
        title: const Text('Исполнитель'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dc, 'none'),
            child: const Text('Не назначен'),
          ),
          for (final m in members)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dc, m.user.id),
              child: Text(m.user.name),
            ),
        ],
      ),
    );
    if (res == null || !context.mounted) return;
    final id = res is int ? res : null;
    await runAction(context, cubit.assign(id, actorId: actor));
  }
}

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.actorId});
  final int? actorId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LastUndoableCubit, ViewState<HistoryEntry?>>(
      builder: (context, state) {
        final last = switch (state) {
          ViewSuccess<HistoryEntry?>(:final data) => data,
          _ => null,
        };
        final can = last != null && last.oldStatus != null;
        return OutlinedButton.icon(
          key: const Key('undoButton'),
          onPressed: can
              ? () => runAction(
                  context,
                  context.read<TaskDetailCubit>().undo(actorId: actorId),
                )
              : null,
          icon: const Icon(Icons.undo),
          label: Text(
            can
                ? 'Отменить: ${last.oldStatus!.label} ← ${last.newStatus.label}'
                : 'Нечего отменять',
          ),
        );
      },
    );
  }
}
