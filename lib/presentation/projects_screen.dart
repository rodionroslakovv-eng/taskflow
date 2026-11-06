import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../repositories/repositories.dart';
import '../state/app_state.dart';
import 'project_detail_screen.dart';
import 'widgets.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        key: const Key('addProjectFab'),
        onPressed: () => showProjectDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ProjectRow>>(
        stream: repos.projects.watchProjects(),
        builder: (context, snap) {
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const EmptyState(
              'Проектов пока нет.\nНажмите «+», чтобы создать.',
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final p = list[i];
              return ListTile(
                title: Text(p.name),
                subtitle: Text(
                  '${p.description.isEmpty ? 'Без описания' : p.description}\n'
                  'Создан: ${fmtDate(p.createdAt)}'
                  '${p.finishedAt != null ? '  •  Завершение: ${fmtDate(p.finishedAt!)}' : ''}',
                ),
                isThreeLine: true,
                trailing: LabelChip(p.status.label, switch (p.status) {
                  ProjectStatus.active => Colors.green,
                  ProjectStatus.completed => Colors.blue,
                  ProjectStatus.archived => Colors.grey,
                }),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(projectId: p.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> showProjectDialog(
  BuildContext context, {
  ProjectRow? project,
}) async {
  final repos = context.read<Repositories>();
  final currentUser = context.read<AppState>().currentUserId;
  final name = TextEditingController(text: project?.name ?? '');
  final desc = TextEditingController(text: project?.description ?? '');
  var status = project?.status ?? ProjectStatus.active;
  DateTime? finished = project?.finishedAt;

  await showDialog<void>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (dc, setState) => AlertDialog(
        title: Text(
          project == null ? 'Новый проект' : 'Редактирование проекта',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('projectName'),
                controller: name,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              TextField(
                key: const Key('projectDesc'),
                controller: desc,
                decoration: const InputDecoration(labelText: 'Описание'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ProjectStatus>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Статус'),
                items: [
                  for (final s in ProjectStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => status = v!),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  finished == null
                      ? 'Дата завершения: не задана'
                      : 'Завершение: ${fmtDate(finished!)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (finished != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => finished = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final d = await pickDate(dc, finished);
                        if (d != null) setState(() => finished = d);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc),
            child: const Text('Отмена'),
          ),
          FilledButton(
            key: const Key('saveProject'),
            onPressed: () async {
              final ok = await guard(dc, () async {
                if (project == null) {
                  await repos.projects.createProject(
                    name: name.text,
                    description: desc.text,
                    status: status,
                    finishedAt: finished,
                    ownerId: currentUser,
                  );
                } else {
                  await repos.projects.updateProject(
                    project.id,
                    name: name.text,
                    description: desc.text,
                    status: status,
                    finishedAt: finished,
                  );
                }
                return true;
              });
              if (ok == true && dc.mounted) Navigator.pop(dc);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}
