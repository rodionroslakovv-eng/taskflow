import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/task_list_controller.dart';
import 'task_detail_screen.dart';
import 'widgets.dart';

/// Список задач с поиском, фильтрами, сортировкой и пагинацией.
class TaskListView extends StatefulWidget {
  const TaskListView({super.key, this.projectId, this.assigneeId});

  final int? projectId;

  /// Если задан — список фиксирован на этом исполнителе (фильтр скрыт).
  final int? assigneeId;

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  late final TaskListController _c;

  @override
  void initState() {
    super.initState();
    _c = TaskListController(
      context.read<Repositories>().tasks,
      projectId: widget.projectId,
      assigneeId: widget.assigneeId,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final f = _c.filter;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: TextField(
                key: const Key('taskSearch'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Поиск по названию и описанию',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: _c.setQuery,
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _drop<TaskStatus>('Статус', f.status, {
                    for (final s in TaskStatus.values) s: s.label,
                  }, _c.setStatus),
                  _drop<TaskPriority>('Приоритет', f.priority, {
                    for (final p in TaskPriority.values) p: p.label,
                  }, _c.setPriority),
                  if (widget.assigneeId == null)
                    StreamBuilder<List<UserRow>>(
                      stream: repos.users.watchUsers(),
                      builder: (context, snap) =>
                          _drop<int>('Исполнитель', f.assigneeId, {
                            for (final u in snap.data ?? <UserRow>[])
                              u.id: u.name,
                          }, _c.setAssignee),
                    ),
                  _drop<TaskSort>(
                    'Сортировка',
                    f.sort,
                    const {
                      TaskSort.createdAt: 'По созданию',
                      TaskSort.deadline: 'По дедлайну',
                    },
                    (v) => _c.setSort(v ?? TaskSort.createdAt),
                    clearable: false,
                  ),
                  IconButton(
                    tooltip: f.ascending ? 'По возрастанию' : 'По убыванию',
                    icon: Icon(
                      f.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                    ),
                    onPressed: _c.toggleDirection,
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<TaskItem>>(
                stream: _c.stream,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data!;
                  if (items.isEmpty)
                    return const EmptyState('Задач не найдено');
                  final hasMore = items.length >= _c.limit;
                  return ListView.builder(
                    itemCount: items.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: OutlinedButton(
                            key: const Key('loadMore'),
                            onPressed: _c.loadMore,
                            child: const Text('Загрузить ещё'),
                          ),
                        );
                      }
                      return TaskTile(
                        item: items[i],
                        showProject: widget.projectId == null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _drop<T>(
    String label,
    T? value,
    Map<T, String> options,
    ValueChanged<T?> onChanged, {
    bool clearable = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<Object>(
        tooltip: label,
        onSelected: (v) => onChanged(identical(v, _clearValue) ? null : v as T),
        itemBuilder: (_) => [
          if (clearable)
            PopupMenuItem<Object>(
              value: _clearValue,
              child: Text('Все: $label'),
            ),
          for (final e in options.entries)
            PopupMenuItem<Object>(value: e.key as Object, child: Text(e.value)),
        ],
        child: Chip(
          label: Text(value == null ? label : options[value] ?? label),
          backgroundColor: value != null && clearable
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
        ),
      ),
    );
  }
}

const Object _clearValue = Object();

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.item,
    this.showProject = true,
    this.trailing,
  });

  final TaskItem item;
  final bool showProject;
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
      trailing: trailing,
      onTap: trailing != null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t.id)),
            ),
    );
  }
}
