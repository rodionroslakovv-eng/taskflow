import '../database/app_database.dart';
import 'attachment_repository.dart';
import 'comment_repository.dart';
import 'project_repository.dart';
import 'stats_repository.dart';
import 'task_repository.dart';
import 'user_repository.dart';

/// Единая точка доступа ко всем репозиториям. UI работает с БД только через них.
class Repositories {
  Repositories(this.db)
    : users = UserRepository(db),
      projects = ProjectRepository(db),
      tasks = TaskRepository(db),
      comments = CommentRepository(db),
      attachments = AttachmentRepository(db),
      stats = StatsRepository(db);

  final AppDatabase db;
  final UserRepository users;
  final ProjectRepository projects;
  final TaskRepository tasks;
  final CommentRepository comments;
  final AttachmentRepository attachments;
  final StatsRepository stats;
}
