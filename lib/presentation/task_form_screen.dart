import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/app_state.dart';
import 'widgets.dart';

/// Создание (task == null) и редактирование задачи.
/// Если [projectId] не задан, проект выбирается из списка.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, this.projectId, this.task});

  final int? projectId;
  final TaskRow? task;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
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
  List<ProjectRow> _projects = [];
  List<MemberItem> _members = [];
  bool _saving = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadMembers();
  }

  Future<void> _loadProjects() async {
    final list = await context.read<Repositories>().projects.getProjects();
    if (mounted) setState(() => _projects = list);
  }

  Future<void> _loadMembers() async {
    final pid = _projectId;
    if (pid == null) return;
    final m = await context.read<Repositories>().projects.getMembers(pid);
    if (mounted) setState(() => _members = m);
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repos = context.read<Repositories>();
    final actor = context.read<AppState>().currentUserId;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final ok = await guard(context, () async {
      if (_isEdit) {
        await repos.tasks.updateTask(
          widget.task!.id,
          title: _title.text,
          description: _desc.text,
          priority: _priority,
          deadline: _deadline,
        );
      } else {
        final pid = _projectId;
        if (pid == null) throw TaskFlowException('Выберите проект');
        await repos.tasks.createTask(
          title: _title.text,
          description: _desc.text,
          projectId: pid,
          assigneeId: _assigneeId,
          priority: _priority,
          deadline: _deadline,
          actorId: actor,
        );
      }
      return true;
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
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
                for (final p in _projects)
                  DropdownMenuItem(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) {
                setState(() {
                  _projectId = v;
                  _assigneeId = null;
                });
                _loadMembers();
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
                for (final m in _members)
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
            onPressed: _saving ? null : _save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
