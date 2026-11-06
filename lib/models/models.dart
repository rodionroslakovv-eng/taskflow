import '../database/app_database.dart';
import 'enums.dart';

/// Ошибка бизнес-логики с текстом, который можно показать пользователю.
class TaskFlowException implements Exception {
  TaskFlowException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Задача вместе с именами исполнителя и проекта (результат JOIN).
class TaskItem {
  const TaskItem({required this.task, required this.project, this.assignee});

  final TaskRow task;
  final ProjectRow project;
  final UserRow? assignee;

  bool get isOverdue =>
      task.deadline != null &&
      task.status.isUnfinished &&
      task.deadline!.isBefore(DateTime.now());
}

class MemberItem {
  const MemberItem({required this.member, required this.user});
  final MemberRow member;
  final UserRow user;
}

class CommentItem {
  const CommentItem({required this.comment, required this.author});
  final CommentRow comment;
  final UserRow author;
}

class HistoryItem {
  const HistoryItem({required this.entry, this.user});
  final HistoryRow entry;
  final UserRow? user;
}

/// Параметры списка задач: фильтры, поиск, сортировка и пагинация.
class TaskFilter {
  const TaskFilter({
    this.projectId,
    this.assigneeId,
    this.status,
    this.priority,
    this.query = '',
    this.sort = TaskSort.createdAt,
    this.ascending = false,
    this.onlyDeleted = false,
    this.limit,
    this.offset = 0,
  });

  final int? projectId;
  final int? assigneeId;
  final TaskStatus? status;
  final TaskPriority? priority;
  final String query;
  final TaskSort sort;
  final bool ascending;
  final bool onlyDeleted;
  final int? limit;
  final int offset;

  TaskFilter copyWith({
    Object? projectId = _keep,
    Object? assigneeId = _keep,
    Object? status = _keep,
    Object? priority = _keep,
    String? query,
    TaskSort? sort,
    bool? ascending,
    bool? onlyDeleted,
    Object? limit = _keep,
    int? offset,
  }) {
    return TaskFilter(
      projectId: identical(projectId, _keep)
          ? this.projectId
          : projectId as int?,
      assigneeId: identical(assigneeId, _keep)
          ? this.assigneeId
          : assigneeId as int?,
      status: identical(status, _keep) ? this.status : status as TaskStatus?,
      priority: identical(priority, _keep)
          ? this.priority
          : priority as TaskPriority?,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      ascending: ascending ?? this.ascending,
      onlyDeleted: onlyDeleted ?? this.onlyDeleted,
      limit: identical(limit, _keep) ? this.limit : limit as int?,
      offset: offset ?? this.offset,
    );
  }
}

const Object _keep = Object();

class PriorityCount {
  const PriorityCount(this.priority, this.count);
  final TaskPriority priority;
  final int count;
}

class AssigneeCount {
  const AssigneeCount(this.userId, this.name, this.count);
  final int userId;
  final String name;
  final int count;
}

class ProjectProgress {
  const ProjectProgress({
    required this.projectId,
    required this.name,
    required this.total,
    required this.done,
    required this.percent,
  });
  final int projectId;
  final String name;
  final int total;
  final int done;
  final double percent;
}

class DashboardStats {
  const DashboardStats({
    required this.projects,
    required this.totalTasks,
    required this.doneTasks,
    required this.unfinishedTasks,
    required this.overdueTasks,
    required this.byPriority,
    required this.byAssignee,
    required this.projectProgress,
  });

  final int projects;
  final int totalTasks;
  final int doneTasks;
  final int unfinishedTasks;
  final int overdueTasks;
  final List<PriorityCount> byPriority;
  final List<AssigneeCount> byAssignee;
  final List<ProjectProgress> projectProgress;
}
