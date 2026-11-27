import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../constants/app_colors.dart';
import '../../../core/di/injection_container.dart';
import '../../domain/entities/project.dart';
import '../bloc/projects/projects_cubits.dart';
import '../bloc/users/users_cubits.dart';
import '../widgets/project_dialog.dart';
import '../widgets/view_state_builder.dart';
import 'project_detail_page.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProjectsCubit>(
      create: (_) => getIt<ProjectsCubit>()..load(),
      child: Builder(
        builder: (context) => Scaffold(
          floatingActionButton: FloatingActionButton(
            heroTag: null,
            key: const Key('addProjectFab'),
            onPressed: () {
              final cubit = context.read<ProjectsCubit>();
              final owner = context.read<CurrentUserCubit>().state.userId;
              showProjectDialog(
                context,
                onSave: (name, description, status, finishedAt) => cubit.create(
                  name: name,
                  description: description,
                  status: status,
                  finishedAt: finishedAt,
                  ownerId: owner,
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
          body: ViewStateBuilder<ProjectsCubit, List<Project>>(
            emptyText: 'Проектов пока нет.\nНажмите «+», чтобы создать.',
            builder: (context, list) => ListView.separated(
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
                  trailing: LabelChip(
                    p.status.label,
                    projectStatusColor(p.status),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectDetailPage(projectId: p.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
