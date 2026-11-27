import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/project.dart';
import 'run_action.dart';

typedef ProjectSaveCallback =
    Future<Either<Failure, Unit>> Function(
      String name,
      String description,
      ProjectStatus status,
      DateTime? finishedAt,
    );

/// Диалог создания / редактирования проекта. Сохранение — через [onSave]
/// (UseCase вызывает Cubit вызывающего экрана).
Future<void> showProjectDialog(
  BuildContext context, {
  Project? project,
  required ProjectSaveCallback onSave,
}) async {
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
              final ok = await runAction(
                dc,
                onSave(name.text, desc.text, status, finished),
              );
              if (ok != null && dc.mounted) Navigator.pop(dc);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ),
  );
}
