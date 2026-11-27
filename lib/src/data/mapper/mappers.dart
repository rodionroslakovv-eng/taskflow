import '../../../models/app_database.dart';
import '../../../models/relation_models.dart';
import '../../../models/stats_models.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/entities/benchmark.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/stats.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/user.dart';

/// Преобразование Model (DTO Data Layer) → Entity (Domain).
/// Модели БД не должны попадать в Presentation Layer.

extension UserRowMapper on UserRow {
  User toEntity() =>
      User(id: id, name: name, email: email, registeredAt: registeredAt);
}

extension ProjectRowMapper on ProjectRow {
  Project toEntity() => Project(
    id: id,
    name: name,
    description: description,
    createdAt: createdAt,
    finishedAt: finishedAt,
    status: status,
  );
}

extension MemberModelMapper on MemberModel {
  ProjectMember toEntity() => ProjectMember(
    id: member.id,
    projectId: member.projectId,
    user: user.toEntity(),
    role: member.role,
    joinedAt: member.joinedAt,
  );
}

extension TaskRowMapper on TaskRow {
  Task toEntity() => Task(
    id: id,
    title: title,
    description: description,
    projectId: projectId,
    assigneeId: assigneeId,
    priority: priority,
    status: status,
    deadline: deadline,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
  );
}

extension TaskItemModelMapper on TaskItemModel {
  TaskItem toEntity() => TaskItem(
    task: task.toEntity(),
    project: project.toEntity(),
    assignee: assignee?.toEntity(),
  );
}

extension CommentModelMapper on CommentModel {
  CommentItem toEntity() => CommentItem(
    comment: Comment(
      id: comment.id,
      body: comment.body,
      authorId: comment.authorId,
      taskId: comment.taskId,
      createdAt: comment.createdAt,
    ),
    author: author.toEntity(),
  );
}

extension AttachmentRowMapper on AttachmentRow {
  Attachment toEntity() => Attachment(
    id: id,
    fileName: fileName,
    filePath: filePath,
    taskId: taskId,
    addedAt: addedAt,
  );
}

extension HistoryRowMapper on HistoryRow {
  HistoryEntry toEntity() => HistoryEntry(
    id: id,
    taskId: taskId,
    kind: kind,
    oldStatus: oldStatus,
    newStatus: newStatus,
    changedBy: changedBy,
    changedAt: changedAt,
    note: note,
    undone: undone,
  );
}

extension HistoryModelMapper on HistoryModel {
  HistoryItem toEntity() =>
      HistoryItem(entry: entry.toEntity(), user: user?.toEntity());
}

extension DashboardStatsModelMapper on DashboardStatsModel {
  DashboardStats toEntity() => DashboardStats(
    projects: projects,
    totalTasks: totalTasks,
    doneTasks: doneTasks,
    unfinishedTasks: unfinishedTasks,
    overdueTasks: overdueTasks,
    byPriority: [
      for (final e in byPriority)
        PriorityCount(TaskPriority.values[e.priorityIndex], e.count),
    ],
    byAssignee: [
      for (final e in byAssignee) AssigneeCount(e.userId, e.name, e.count),
    ],
    projectProgress: [
      for (final e in projectProgress)
        ProjectProgress(
          projectId: e.projectId,
          name: e.name,
          total: e.total,
          done: e.done,
          percent: e.percent,
        ),
    ],
  );
}

extension BenchmarkReportModelMapper on BenchmarkReportModel {
  BenchmarkReport toEntity() => BenchmarkReport(
    seedMs: seedMs,
    results: [
      for (final r in results)
        BenchmarkResult(r.name, r.withIndexMs, r.withoutIndexMs),
    ],
  );
}
