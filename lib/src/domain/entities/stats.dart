import 'package:equatable/equatable.dart';

import 'enums.dart';

class PriorityCount extends Equatable {
  const PriorityCount(this.priority, this.count);
  final TaskPriority priority;
  final int count;

  @override
  List<Object?> get props => [priority, count];
}

class AssigneeCount extends Equatable {
  const AssigneeCount(this.userId, this.name, this.count);
  final int userId;
  final String name;
  final int count;

  @override
  List<Object?> get props => [userId, name, count];
}

class ProjectProgress extends Equatable {
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

  @override
  List<Object?> get props => [projectId, name, total, done, percent];
}

class DashboardStats extends Equatable {
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

  @override
  List<Object?> get props => [
    projects,
    totalTasks,
    doneTasks,
    unfinishedTasks,
    overdueTasks,
    byPriority,
    byAssignee,
    projectProgress,
  ];
}
