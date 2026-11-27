import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/error/failure_message.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/task.dart';
import '../bloc/tasks/task_cubits.dart';
import '../bloc/users/users_cubits.dart';
import '../widgets/run_action.dart';

/// Создание (task == null) и редактирование задачи.
/// Если [projectId] не задан, проект выбирается из списка.
class TaskFormPage extends StatelessWidget {
  const TaskFormPage({super.key, this.projectId, this.task});

  final int? projectId;
  final Task? task;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TaskFormCubit>(
      create: (_) => getIt<TaskFormCubit>()
        ..loadProjects()
        ..loadMembers(projectId ?? task?.projectId),
      child: BlocListener<TaskFormCubit, TaskFormState>(
        listenWhen: (a, b) => a.loadFailure != b.loadFailure,
        listener: (context, state) {
          final failure = state.loadFailure;
          if (failure != null) showSnack(context, failureMessage(failure));
        },
        child: _TaskForm(projectId: projectId, task: task),
      ),
    );
  }
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({this.projectId, this.task});
  final int? projectId;
  final Task? task;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final TextEditingController _title = TextEditingController(
    text: widget.task?.title ?? '',
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.task?.description ?? '',
  );
  late int? _projectId = widget.projectId ?? widget.task?.projectId;
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.medium;
  late DateTime? _deadline = widget.task?.deadline;
  int? _assigneeId;

  bool get _isEdit => widget.task != null;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<TaskFormCubit>();
    final actor = context.read<CurrentUserCubit>().state.userId;
    final nav = Navigator.of(context);
    final result = _isEdit
        ? cubit.update(
            widget.task!.id,
            title: _title.text,
            description: _desc.text,
            priority: _priority,
            deadline: _deadline,
          )
        : cubit.create(
            title: _title.text,
            description: _desc.text,
            projectId: _projectId,
            assigneeId: _assigneeId,
            priority: _priority,
            deadline: _deadline,
            actorId: actor,
          );
    final ok = await runAction(context, result);
    if (ok != null) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TaskFormCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Редактирование задачи' : 'Новая задача'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_isEdit && widget.projectId == null)
            DropdownButtonFormField<int>(
              key: const Key('taskProject'),
              initialValue: _projectId,
              decoration: const InputDecoration(labelText: 'Проект'),
              items: [
                for (final p in state.projects)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) {
                setState(() {
                  _projectId = v;
                  _assigneeId = null;
                });
                context.read<TaskFormCubit>().loadMembers(v);
              },
            ),
          TextField(
            key: const Key('taskTitle'),
            controller: _title,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          TextField(
            key: const Key('taskDesc'),
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Описание'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Приоритет'),
            items: [
              for (final p in TaskPriority.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
            onChanged: (v) => setState(() => _priority = v!),
          ),
          if (!_isEdit)
            DropdownButtonFormField<int?>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(labelText: 'Исполнитель'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Не назначен'),
                ),
                for (final m in state.members)
                  DropdownMenuItem<int?>(
                    value: m.user.id,
                    child: Text(m.user.name),
                  ),
              ],
              onChanged: (v) => setState(() => _assigneeId = v),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _deadline == null
                  ? 'Дедлайн не задан'
                  : 'Дедлайн: ${fmtDate(_deadline!)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_deadline != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _deadline = null),
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final d = await pickDate(context, _deadline);
                    if (d != null) setState(() => _deadline = d);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('saveTask'),
            onPressed: state.saving ? null : _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
