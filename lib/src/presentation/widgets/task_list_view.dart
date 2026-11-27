import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/error/failure_message.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user.dart';
import '../bloc/common/view_state.dart';
import '../bloc/tasks/task_list_cubit.dart';
import '../bloc/users/users_cubits.dart';
import 'task_tile.dart';

/// Список задач с поиском, фильтрами, сортировкой и пагинацией.
class TaskListView extends StatelessWidget {
  const TaskListView({super.key, this.projectId, this.assigneeId});

  final int? projectId;

  /// Если задан — список фиксирован на этом исполнителе (фильтр скрыт).
  final int? assigneeId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TaskListCubit>(
      create: (_) => getIt<TaskListCubit>(
        param1: TaskFilter(projectId: projectId, assigneeId: assigneeId),
      )..load(),
      child: _TaskListBody(
        showProject: projectId == null,
        showAssigneeFilter: assigneeId == null,
      ),
    );
  }
}

class _TaskListBody extends StatelessWidget {
  const _TaskListBody({
    required this.showProject,
    required this.showAssigneeFilter,
  });

  final bool showProject;
  final bool showAssigneeFilter;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaskListCubit>();
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
            onChanged: cubit.setQuery,
          ),
        ),
        BlocBuilder<TaskListCubit, TaskListState>(
          buildWhen: (a, b) => a.filter != b.filter,
          builder: (context, state) =>
              _Filters(filter: state.filter, showAssignee: showAssigneeFilter),
        ),
        Expanded(
          child: BlocBuilder<TaskListCubit, TaskListState>(
            builder: (context, state) => switch (state.view) {
              ViewInitial<List<TaskItem>>() ||
              ViewLoading<List<TaskItem>>() => const LoadingView(),
              ViewEmpty<List<TaskItem>>() => const EmptyState('Задач не найдено'),
              ViewError<List<TaskItem>>(:final failure) => ErrorView(
                message: failureMessage(failure),
                onRetry: cubit.retry,
              ),
              ViewSuccess<List<TaskItem>>(:final data) => _TaskList(
                items: data,
                hasMore: state.hasMore,
                showProject: showProject,
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.items,
    required this.hasMore,
    required this.showProject,
  });

  final List<TaskItem> items;
  final bool hasMore;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == items.length) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton(
              key: const Key('loadMore'),
              onPressed: context.read<TaskListCubit>().loadMore,
              child: const Text('Загрузить ещё'),
            ),
          );
        }
        return TaskTile(item: items[i], showProject: showProject);
      },
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.filter, required this.showAssignee});

  final TaskFilter filter;
  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaskListCubit>();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _drop<TaskStatus>(context, 'Статус', filter.status, {
            for (final s in TaskStatus.values) s: s.label,
          }, cubit.setStatus),
          _drop<TaskPriority>(context, 'Приоритет', filter.priority, {
            for (final p in TaskPriority.values) p: p.label,
          }, cubit.setPriority),
          if (showAssignee)
            BlocBuilder<UsersCubit, ViewState<List<User>>>(
              builder: (context, state) {
                final users = switch (state) {
                  ViewSuccess<List<User>>(:final data) => data,
                  _ => const <User>[],
                };
                return _drop<int>(context, 'Исполнитель', filter.assigneeId, {
                  for (final u in users) u.id: u.name,
                }, cubit.setAssignee);
              },
            ),
          _drop<TaskSort>(
            context,
            'Сортировка',
            filter.sort,
            const {
              TaskSort.createdAt: 'По созданию',
              TaskSort.deadline: 'По дедлайну',
            },
            (v) => cubit.setSort(v ?? TaskSort.createdAt),
            clearable: false,
          ),
          IconButton(
            tooltip: filter.ascending ? 'По возрастанию' : 'По убыванию',
            icon: Icon(
              filter.ascending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            onPressed: cubit.toggleDirection,
          ),
        ],
      ),
    );
  }

  Widget _drop<T>(
    BuildContext context,
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
