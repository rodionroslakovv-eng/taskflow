class PriorityCountModel {
  const PriorityCountModel(this.priorityIndex, this.count);
  final int priorityIndex;
  final int count;
}

class AssigneeCountModel {
  const AssigneeCountModel(this.userId, this.name, this.count);
  final int userId;
  final String name;
  final int count;
}

class ProjectProgressModel {
  const ProjectProgressModel({
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

class DashboardStatsModel {
  const DashboardStatsModel({
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
  final List<PriorityCountModel> byPriority;
  final List<AssigneeCountModel> byAssignee;
  final List<ProjectProgressModel> projectProgress;
}

class BenchmarkResultModel {
  const BenchmarkResultModel(this.name, this.withIndexMs, this.withoutIndexMs);
  final String name;
  final double withIndexMs;
  final double withoutIndexMs;
}

class BenchmarkReportModel {
  const BenchmarkReportModel({required this.seedMs, required this.results});
  final int seedMs;
  final List<BenchmarkResultModel> results;
}
