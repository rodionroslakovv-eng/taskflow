import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'user.dart';

class HistoryEntry extends Equatable {
  const HistoryEntry({
    required this.id,
    required this.taskId,
    required this.kind,
    required this.newStatus,
    required this.changedAt,
    required this.undone,
    this.oldStatus,
    this.changedBy,
    this.note,
  });

  final int id;
  final int taskId;
  final HistoryKind kind;

  /// null для записи о создании задачи.
  final TaskStatus? oldStatus;
  final TaskStatus newStatus;
  final int? changedBy;
  final DateTime changedAt;
  final String? note;

  /// Запись уже отменена через Undo.
  final bool undone;

  @override
  List<Object?> get props => [
    id,
    taskId,
    kind,
    oldStatus,
    newStatus,
    changedBy,
    changedAt,
    note,
    undone,
  ];
}

class HistoryItem extends Equatable {
  const HistoryItem({required this.entry, this.user});

  final HistoryEntry entry;
  final User? user;

  @override
  List<Object?> get props => [entry, user];
}
