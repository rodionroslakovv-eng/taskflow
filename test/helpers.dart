import 'package:drift/native.dart';
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/repositories/attachment_repository.dart';
import 'package:taskflow/repositories/comment_repository.dart';
import 'package:taskflow/repositories/project_repository.dart';
import 'package:taskflow/repositories/stats_repository.dart';
import 'package:taskflow/repositories/task_repository.dart';
import 'package:taskflow/repositories/user_repository.dart';

class TestEnv {
  TestEnv() : db = AppDatabase(NativeDatabase.memory()) {
    users = UserRepository(db);
    projects = ProjectRepository(db);
    tasks = TaskRepository(db);
    comments = CommentRepository(db);
    attachments = AttachmentRepository(db);
    stats = StatsRepository(db);
  }

  final AppDatabase db;
  late final UserRepository users;
  late final ProjectRepository projects;
  late final TaskRepository tasks;
  late final CommentRepository comments;
  late final AttachmentRepository attachments;
  late final StatsRepository stats;

  Future<void> close() => db.close();

  int _n = 0;

  Future<int> user([String? name]) {
    _n++;
    return users.createUser(name: name ?? 'User $_n', email: 'u$_n@mail.com');
  }
}
