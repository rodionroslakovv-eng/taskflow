import 'app_database.dart';

/// DTO-модели Data Layer: строки БД, собранные JOIN-запросами.
/// Преобразуются в Domain-сущности мапперами (`src/data/mapper`).

class MemberModel {
  const MemberModel({required this.member, required this.user});
  final MemberRow member;
  final UserRow user;
}

class TaskItemModel {
  const TaskItemModel({
    required this.task,
    required this.project,
    this.assignee,
  });
  final TaskRow task;
  final ProjectRow project;
  final UserRow? assignee;
}

class CommentModel {
  const CommentModel({required this.comment, required this.author});
  final CommentRow comment;
  final UserRow author;
}

class HistoryModel {
  const HistoryModel({required this.entry, this.user});
  final HistoryRow entry;
  final UserRow? user;
}
