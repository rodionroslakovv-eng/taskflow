import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../core/di/injection_container.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/history.dart';
import '../bloc/tasks/task_cubits.dart';
import '../bloc/users/users_cubits.dart';
import 'run_action.dart';
import 'view_state_builder.dart';

// ---------------------------------------------------------------- история

class HistorySection extends StatelessWidget {
  const HistorySection({super.key, required this.taskId});
  final int taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TaskHistoryCubit>(
      create: (_) => getIt<TaskHistoryCubit>(param1: taskId)..load(),
      child: ExpansionTile(
        title: const Text('История изменений'),
        initiallyExpanded: true,
        children: [
          ViewStateBuilder<TaskHistoryCubit, List<HistoryItem>>(
            emptyText: 'История пуста',
            builder: (context, list) => Column(
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
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------- комментарии

class CommentsSection extends StatelessWidget {
  const CommentsSection({
    super.key,
    required this.taskId,
    required this.readOnly,
  });
  final int taskId;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommentsCubit>(
      create: (_) => getIt<CommentsCubit>(param1: taskId)..load(),
      child: _CommentsBody(readOnly: readOnly),
    );
  }
}

class _CommentsBody extends StatefulWidget {
  const _CommentsBody({required this.readOnly});
  final bool readOnly;

  @override
  State<_CommentsBody> createState() => _CommentsBodyState();
}

class _CommentsBodyState extends State<_CommentsBody> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<CurrentUserCubit>().state.userId;
    final cubit = context.read<CommentsCubit>();
    return ExpansionTile(
      title: const Text('Комментарии'),
      initiallyExpanded: true,
      children: [
        ViewStateBuilder<CommentsCubit, List<CommentItem>>(
          emptyBuilder: (_) => const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Комментариев нет'),
          ),
          builder: (context, list) => Column(
            children: [
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
                          onPressed: () => runAction(
                            context,
                            cubit.delete(c.comment.id, requesterId: me!),
                          ),
                        )
                      : null,
                ),
            ],
          ),
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
                    final ok = await runAction(
                      context,
                      cubit.add(authorId: me, body: _text.text),
                    );
                    if (ok != null) _text.clear();
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

class AttachmentsSection extends StatelessWidget {
  const AttachmentsSection({
    super.key,
    required this.taskId,
    required this.readOnly,
  });
  final int taskId;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AttachmentsCubit>(
      create: (_) => getIt<AttachmentsCubit>(param1: taskId)..load(),
      child: Builder(
        builder: (context) => ExpansionTile(
          title: const Text('Вложения'),
          children: [
            ViewStateBuilder<AttachmentsCubit, List<Attachment>>(
              emptyBuilder: (_) => const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Вложений нет'),
              ),
              builder: (context, list) => Column(
                children: [
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
                              onPressed: () => runAction(
                                context,
                                context.read<AttachmentsCubit>().delete(a.id),
                              ),
                            ),
                    ),
                ],
              ),
            ),
            if (!readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _pick(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Прикрепить файл'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<AttachmentsCubit>();
    final picked = await FilePicker.pickFile();
    if (picked == null || !context.mounted) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    await runAction(context, cubit.add(picked.name, bytes));
  }
}
