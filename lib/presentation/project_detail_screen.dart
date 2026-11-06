import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'projects_screen.dart';
import 'task_form_screen.dart';
import 'task_list_view.dart';
import 'widgets.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final int projectId;

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return StreamBuilder<ProjectRow?>(
      stream: repos.projects.watchProject(projectId),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState('Проект не найден'),
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
                  onPressed: () => showProjectDialog(context, project: p),
                ),
                IconButton(
                  tooltip: 'Удалить проект',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(
                          context,
                          'Удалить проект «${p.name}» вместе со всеми задачами?',
                        ) &&
                        context.mounted) {
                      final nav = Navigator.of(context);
                      final ok = await guard(
                        context,
                        () => repos.projects
                            .deleteProject(p.id)
                            .then((_) => true),
                      );
                      if (ok == true) nav.pop();
                    }
                  },
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
    );
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
            builder: (_) => TaskFormScreen(projectId: projectId),
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
    final repos = context.read<Repositories>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _addMember(context),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<List<MemberItem>>(
        stream: repos.projects.watchMembers(projectId),
        builder: (context, snap) {
          final list = snap.data ?? [];
          if (list.isEmpty)
            return const EmptyState('В проекте пока нет участников');
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
                      value: m.member.role,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final r in MemberRole.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (r) => guard(
                        context,
                        () => repos.projects.setRole(projectId, m.user.id, r!),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Убрать из проекта',
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () => guard(
                        context,
                        () => repos.projects.removeMember(projectId, m.user.id),
                      ),
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

  Future<void> _addMember(BuildContext context) async {
    final repos = context.read<Repositories>();
    final all = await repos.users.getUsers();
    final members = await repos.projects.getMembers(projectId);
    final taken = members.map((m) => m.user.id).toSet();
    final free = all.where((u) => !taken.contains(u.id)).toList();
    if (!context.mounted) return;
    if (free.isEmpty) {
      showSnack(context, 'Нет пользователей, которых можно добавить');
      return;
    }
    UserRow selected = free.first;
    var role = MemberRole.member;
    await showDialog<void>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, setState) => AlertDialog(
          title: const Text('Добавить участника'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRow>(
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
                final ok = await guard(dc, () async {
                  await repos.projects.addMember(
                    projectId: projectId,
                    userId: selected.id,
                    role: role,
                  );
                  return true;
                });
                if (ok == true && dc.mounted) Navigator.pop(dc);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }
}
