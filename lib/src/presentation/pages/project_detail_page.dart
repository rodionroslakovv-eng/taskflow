import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../core/di/injection_container.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/user.dart';
import '../bloc/common/view_state.dart';
import '../bloc/projects/projects_cubits.dart';
import '../widgets/project_dialog.dart';
import '../widgets/run_action.dart';
import '../widgets/task_list_view.dart';
import '../widgets/view_state_builder.dart';
import 'task_form_page.dart';

class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({super.key, required this.projectId});
  final int projectId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProjectDetailCubit>(
      create: (_) => getIt<ProjectDetailCubit>(param1: projectId)..load(),
      child: BlocBuilder<ProjectDetailCubit, ViewState<Project?>>(
        builder: (context, state) {
          final p = switch (state) {
            ViewSuccess<Project?>(:final data) => data,
            _ => null,
          };
          if (p == null) {
            return Scaffold(
              appBar: AppBar(),
              body: switch (state) {
                ViewInitial<Project?>() ||
                ViewLoading<Project?>() => const LoadingView(),
                ViewError<Project?>() => ErrorView(
                  message: 'Не удалось загрузить проект',
                  onRetry: context.read<ProjectDetailCubit>().retry,
                ),
                _ => const EmptyState('Проект не найден'),
              },
            );
          }
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: Text(p.name),
                actions: [
                  IconButton(
                    tooltip: 'Редактировать',
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      final cubit = context.read<ProjectDetailCubit>();
                      showProjectDialog(
                        context,
                        project: p,
                        onSave: (name, description, status, finishedAt) =>
                            cubit.update(
                              name: name,
                              description: description,
                              status: status,
                              finishedAt: finishedAt,
                            ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Удалить проект',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(context, p),
                  ),
                ],
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Задачи'),
                    Tab(text: 'Участники'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  _TasksTab(projectId: p.id),
                  _MembersTab(projectId: p.id),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context, Project p) async {
    final cubit = context.read<ProjectDetailCubit>();
    final nav = Navigator.of(context);
    if (!await confirm(
          context,
          'Удалить проект «${p.name}» вместе со всеми задачами?',
        ) ||
        !context.mounted) {
      return;
    }
    final ok = await runAction(context, cubit.delete());
    if (ok != null) nav.pop();
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.projectId});
  final int projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        key: const Key('addTaskFab'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskFormPage(projectId: projectId),
          ),
        ),
        child: const Icon(Icons.add_task),
      ),
      body: TaskListView(projectId: projectId),
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.projectId});
  final int projectId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProjectMembersCubit>(
      create: (_) => getIt<ProjectMembersCubit>(param1: projectId)..load(),
      child: Builder(
        builder: (context) => Scaffold(
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            onPressed: () => _addMember(context),
            child: const Icon(Icons.person_add),
          ),
          body: ViewStateBuilder<ProjectMembersCubit, List<ProjectMember>>(
            emptyText: 'В проекте пока нет участников',
            builder: (context, list) {
              final cubit = context.read<ProjectMembersCubit>();
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final m = list[i];
                  return ListTile(
                    title: Text(m.user.name),
                    subtitle: Text(m.user.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButton<MemberRole>(
                          value: m.role,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final r in MemberRole.values)
                              DropdownMenuItem(value: r, child: Text(r.label)),
                          ],
                          onChanged: (r) =>
                              runAction(context, cubit.setRole(m.user.id, r!)),
                        ),
                        IconButton(
                          tooltip: 'Убрать из проекта',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () =>
                              runAction(context, cubit.remove(m.user.id)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _addMember(BuildContext context) async {
    final cubit = context.read<ProjectMembersCubit>();
    final free = await runAction(context, cubit.addableUsers());
    if (free == null || !context.mounted) return;
    if (free.isEmpty) {
      showSnack(context, 'Нет пользователей, которых можно добавить');
      return;
    }
    User selected = free.first;
    var role = MemberRole.member;
    await showDialog<void>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, setState) => AlertDialog(
          title: const Text('Добавить участника'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<User>(
                initialValue: selected,
                isExpanded: true,
                items: [
                  for (final u in free)
                    DropdownMenuItem(
                      value: u,
                      child: Text('${u.name} (${u.email})'),
                    ),
                ],
                onChanged: (u) => setState(() => selected = u!),
              ),
              DropdownButtonFormField<MemberRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Роль'),
                items: [
                  for (final r in MemberRole.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (r) => setState(() => role = r!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await runAction(dc, cubit.add(selected.id, role));
                if (ok != null && dc.mounted) Navigator.pop(dc);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}
