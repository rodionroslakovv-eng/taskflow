import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/enums.dart';
import '../models/models.dart';

final _dateFmt = DateFormat('dd.MM.yyyy');
final _dateTimeFmt = DateFormat('dd.MM.yyyy HH:mm');

String fmtDate(DateTime d) => _dateFmt.format(d);
String fmtDateTime(DateTime d) => _dateTimeFmt.format(d);

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Выполняет действие и показывает ошибку бизнес-логики в SnackBar.
Future<T?> guard<T>(BuildContext context, Future<T> Function() action) async {
  try {
    return await action();
  } on TaskFlowException catch (e) {
    if (context.mounted) showSnack(context, e.message);
  } catch (e) {
    if (context.mounted) showSnack(context, 'Ошибка: $e');
  }
  return null;
}

Future<bool> confirm(
  BuildContext context,
  String text, {
  String yes = 'Удалить',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
      ],
    ),
  );
  return res ?? false;
}

Color priorityColor(TaskPriority p) => switch (p) {
  TaskPriority.low => Colors.green,
  TaskPriority.medium => Colors.blue,
  TaskPriority.high => Colors.orange,
  TaskPriority.critical => Colors.red,
};

Color statusColor(TaskStatus s) => switch (s) {
  TaskStatus.todo => Colors.grey,
  TaskStatus.inProgress => Colors.indigo,
  TaskStatus.done => Colors.green,
  TaskStatus.cancelled => Colors.brown,
};

class LabelChip extends StatelessWidget {
  const LabelChip(this.text, this.color, {super.key});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

Future<DateTime?> pickDate(BuildContext context, DateTime? initial) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
}
