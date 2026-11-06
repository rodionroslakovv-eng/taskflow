import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../models/enums.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/app_state.dart';
import 'task_form_screen.dart';
import 'widgets.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    final actor = context.watch<AppState>().currentUserId;
    return StreamBuilder<TaskItem?>(
      stream: repos.tasks.watchTask(taskId),
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: snap.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : const EmptyState('Задача не найдена'),
          );
        }
        final t = item.task;
        final inTrash = t.deletedAt != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Задача'),
            actions: [
              if (!inTrash)
                IconButton(
                  tooltip: 'Редактировать',
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TaskFormScreen(task: t)),
                  ),
                ),
              if (!inTrash)
                IconButton(
                  tooltip: 'В корзину',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final ok = await guard(
                      context,
                      () => repos.tasks.softDelete(t.id).then((_) => true),
                    );
                    if (ok == true) {
                      nav.pop();
                    }
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
              _infoRow(
                'Дедлайн',
                t.deadline == null ? '—' : fmtDate(t.deadline!),
              ),
              const Divider(),
              if (!inTrash) _controls(context, repos, item, actor),
              const Divider(),
              _HistorySection(taskId: t.id),
              _CommentsSection(taskId: t.id, readOnly: inTrash),
              _AttachmentsSection(taskId: t.id, readOnly: inTrash),
            ],
          ),
        );
      },
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

  Widget _controls(
    BuildContext context,
    Repositories repos,
    TaskItem item,
    int? actor,
  ) {
    final t = item.task;
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
          onChanged: (s) => guard(
            context,
            () => repos.tasks.changeStatus(t.id, s!, actorId: actor),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<TaskPriority>(
          initialValue: t.priority,
          decoration: const InputDecoration(labelText: 'Приоритет'),
          items: [
            for (final pr in TaskPriority.values)
              DropdownMenuItem(value: pr, child: Text(pr.label)),
          ],
          onChanged: (pr) =>
              guard(context, () => repos.tasks.changePriority(t.id, pr!)),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Исполнитель: ${item.assignee?.name ?? 'не назначен'}'),
          trailing: TextButton(
            onPressed: () => _pickAssignee(context, repos, item, actor),
            child: const Text('Изменить'),
          ),
        ),
        StreamBuilder<HistoryRow?>(
          stream: repos.tasks.watchLastUndoable(t.id),
          builder: (context, snap) {
            final last = snap.data;
            final can = last != null && last.oldStatus != null;
            return OutlinedButton.icon(
              key: const Key('undoButton'),
              onPressed: can
                  ? () => guard(
                      context,
                      () => repos.tasks.undoLastStatusChange(
                        t.id,
                        actorId: actor,
                      ),
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
        ),
      ],
    );
  }

  Future<void> _pickAssignee(
    BuildContext context,
    Repositories repos,
    TaskItem item,
    int? actor,
  ) async {
    final members = await repos.projects.getMembers(item.project.id);
    if (!context.mounted) return;
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
    await guard(
      context,
      () => repos.tasks.assignTask(item.task.id, id, actorId: actor),
    );
  }
}

// ---------------------------------------------------------------- история

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return ExpansionTile(
      title: const Text('История изменений'),
      initiallyExpanded: true,
      children: [
        StreamBuilder<List<HistoryItem>>(
          stream: repos.tasks.watchHistory(taskId),
          builder: (context, snap) {
            final list = snap.data ?? [];
            return Column(
              children: [
                for (final h in list)
                  ListTile(
                    dense: true,
                    leading: Icon(switch (h.entry.kind) {
                      HistoryKind.created => Icons.add_circle_outline,
                      HistoryKind.status => Icons.swap_horiz,
                      HistoryKind.assignee => Icons.person_outline,
                      HistoryKind.undo => Icons.undo,
                    }),
                    title: Text(switch (h.entry.kind) {
                      HistoryKind.created =>
                        'Создана (${h.entry.newStatus.label})',
                      HistoryKind.assignee =>
                        h.entry.note ?? h.entry.kind.label,
                      _ =>
                        '${h.entry.oldStatus?.label ?? '—'} → ${h.entry.newStatus.label}'
                            '${h.entry.kind == HistoryKind.undo ? ' (отмена)' : ''}',
                    }),
                    subtitle: Text(
                      '${h.user?.name ?? 'неизвестно'} • ${fmtDateTime(h.entry.changedAt)}',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------- комментарии

class _CommentsSection extends StatefulWidget {
  const _CommentsSection({required this.taskId, required this.readOnly});
  final int taskId;
  final bool readOnly;

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    final me = context.watch<AppState>().currentUserId;
    return ExpansionTile(
      title: const Text('Комментарии'),
      initiallyExpanded: true,
      children: [
        StreamBuilder<List<CommentItem>>(
          stream: repos.comments.watchComments(widget.taskId),
          builder: (context, snap) {
            final list = snap.data ?? [];
            return Column(
              children: [
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Комментариев нет'),
                  ),
                for (final c in list)
                  ListTile(
                    dense: true,
                    title: Text(c.comment.body),
                    subtitle: Text(
                      '${c.author.name} • ${fmtDateTime(c.comment.createdAt)}',
                    ),
                    trailing: c.author.id == me
                        ? IconButton(
                            tooltip: 'Удалить',
                            icon: const Icon(Icons.close),
                            onPressed: () => guard(
                              context,
                              () => repos.comments.deleteComment(
                                c.comment.id,
                                requesterId: me!,
                              ),
                            ),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        if (!widget.readOnly)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('commentField'),
                    controller: _text,
                    decoration: const InputDecoration(
                      hintText: 'Новый комментарий',
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('sendComment'),
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (me == null) {
                      showSnack(context, 'Выберите текущего пользователя');
                      return;
                    }
                    final ok = await guard(context, () async {
                      await repos.comments.addComment(
                        taskId: widget.taskId,
                        authorId: me,
                        body: _text.text,
                      );
                      return true;
                    });
                    if (ok == true) _text.clear();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------- вложения

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.taskId, required this.readOnly});
  final int taskId;
  final bool readOnly;

  Future<void> _add(BuildContext context, Repositories repos) async {
    final picked = await FilePicker.pickFile();
    if (picked == null) return;
    if (!context.mounted) return;
    await guard(context, () async {
      // Копируем файл в папку приложения, в БД храним только путь.
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'attachments', '$taskId'));
      await dir.create(recursive: true);
      final target = File(
        p.join(
          dir.path,
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}',
        ),
      );
      await target.writeAsBytes(await picked.readAsBytes());
      await repos.attachments.addAttachment(
        taskId: taskId,
        fileName: picked.name,
        filePath: target.path,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return ExpansionTile(
      title: const Text('Вложения'),
      children: [
        StreamBuilder<List<AttachmentRow>>(
          stream: repos.attachments.watchAttachments(taskId),
          builder: (context, snap) {
            final list = snap.data ?? [];
            return Column(
              children: [
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Вложений нет'),
                  ),
                for (final a in list)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.attach_file),
                    title: Text(a.fileName),
                    subtitle: Text('${a.filePath}\n${fmtDateTime(a.addedAt)}'),
                    isThreeLine: true,
                    trailing: readOnly
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              await guard(context, () async {
                                await repos.attachments.deleteAttachment(a.id);
                                final f = File(a.filePath);
                                if (await f.exists()) await f.delete();
                              });
                            },
                          ),
                  ),
              ],
            );
          },
        ),
        if (!readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _add(context, repos),
              icon: const Icon(Icons.add),
              label: const Text('Прикрепить файл'),
            ),
          ),
      ],
    );
  }
}
