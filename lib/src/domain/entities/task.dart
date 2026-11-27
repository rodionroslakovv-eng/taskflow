import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'project.dart';
import 'user.dart';

class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.projectId,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assigneeId,
    this.deadline,
    this.deletedAt,
  });

  final int id;
  final String title;
  final String description;
  final int projectId;
  final int? assigneeId;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? deadline;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Если не null — задача в корзине (soft delete).
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    projectId,
    assigneeId,
    priority,
    status,
    deadline,
    createdAt,
    updatedAt,
    deletedAt,
  ];
}

/// Задача вместе с проектом и исполнителем.
class TaskItem extends Equatable {
  const TaskItem({required this.task, required this.project, this.assignee});

  final Task task;
  final Project project;
  final User? assignee;

  bool get isOverdue =>
      task.deadline != null &&
      task.status.isUnfinished &&
      task.deadline!.isBefore(DateTime.now());

  @override
  List<Object?> get props => [task, project, assignee];
}

/// Параметры списка задач: фильтры, поиск, сортировка и пагинация.
class TaskFilter extends Equatable {
  const TaskFilter({
    this.projectId,
    this.assigneeId,
    this.status,
    this.priority,
    this.taskIds,
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

  /// Если задан — вернуть только задачи с этими id (например, избранное).
  final Set<int>? taskIds;
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
    Object? taskIds = _keep,
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
      taskIds: identical(taskIds, _keep)
          ? this.taskIds
          : taskIds as Set<int>?,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      ascending: ascending ?? this.ascending,
      onlyDeleted: onlyDeleted ?? this.onlyDeleted,
      limit: identical(limit, _keep) ? this.limit : limit as int?,
      offset: offset ?? this.offset,
    );
  }

  @override
  List<Object?> get props => [
    projectId,
    assigneeId,
    status,
    priority,
    taskIds,
    query,
    sort,
    ascending,
    onlyDeleted,
    limit,
    offset,
  ];
}

const Object _keep = Object();
