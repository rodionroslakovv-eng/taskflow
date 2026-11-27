import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/core/utils/either.dart';
import 'package:taskflow/models/app_database.dart';
import 'package:taskflow/src/data/datasources/local/attachment_local_data_source.dart';
import 'package:taskflow/src/data/datasources/local/comment_local_data_source.dart';
import 'package:taskflow/src/data/datasources/local/project_local_data_source.dart';
import 'package:taskflow/src/data/datasources/local/stats_local_data_source.dart';
import 'package:taskflow/src/data/datasources/local/task_local_data_source.dart';
import 'package:taskflow/src/data/datasources/local/user_local_data_source.dart';
import 'package:taskflow/src/data/repositories/attachment_repository_impl.dart';
import 'package:taskflow/src/data/repositories/comment_repository_impl.dart';
import 'package:taskflow/src/data/repositories/project_repository_impl.dart';
import 'package:taskflow/src/data/repositories/stats_repository_impl.dart';
import 'package:taskflow/src/data/repositories/task_repository_impl.dart';
import 'package:taskflow/src/data/repositories/user_repository_impl.dart';
import 'package:taskflow/src/domain/entities/history.dart';
import 'package:taskflow/src/domain/entities/task.dart';
import 'package:taskflow/src/domain/repositories/attachment_repository.dart';
import 'package:taskflow/src/domain/repositories/comment_repository.dart';
import 'package:taskflow/src/domain/repositories/project_repository.dart';
import 'package:taskflow/src/domain/repositories/stats_repository.dart';
import 'package:taskflow/src/domain/repositories/task_repository.dart';
import 'package:taskflow/src/domain/repositories/user_repository.dart';
import 'package:taskflow/src/domain/usecases/comment_usecases.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/domain/usecases/user_usecases.dart';

extension EitherTestX<R> on Either<Failure, R> {
  /// Значение справа; если пришёл Failure — тест падает с понятным сообщением.
  R get value => fold(
    (f) => throw TestFailure('Ожидали Right, получили Left($f)'),
    (r) => r,
  );

  Failure get failure => fold(
    (f) => f,
    (r) => throw TestFailure('Ожидали Left, получили Right($r)'),
  );
}

/// Собирает Data + Domain слои поверх БД в памяти (без GetIt и без UI).
class TestEnv {
  TestEnv() : db = AppDatabase(NativeDatabase.memory()) {
    users = UserRepositoryImpl(UserLocalDataSourceImpl(db));
    projects = ProjectRepositoryImpl(ProjectLocalDataSourceImpl(db));
    tasks = TaskRepositoryImpl(TaskLocalDataSourceImpl(db));
    comments = CommentRepositoryImpl(CommentLocalDataSourceImpl(db));
    attachments = AttachmentRepositoryImpl(AttachmentLocalDataSourceImpl(db));
    stats = StatsRepositoryImpl(StatsLocalDataSourceImpl(db));

    createUser = CreateUserUseCase(users);
    createProject = CreateProjectUseCase(projects);
    createTask = CreateTaskUseCase(tasks);
    updateTask = UpdateTaskUseCase(tasks);
    addComment = AddCommentUseCase(comments);
  }

  final AppDatabase db;
  late final UserRepository users;
  late final ProjectRepository projects;
  late final TaskRepository tasks;
  late final CommentRepository comments;
  late final AttachmentRepository attachments;
  late final StatsRepository stats;

  late final CreateUserUseCase createUser;
  late final CreateProjectUseCase createProject;
  late final CreateTaskUseCase createTask;
  late final UpdateTaskUseCase updateTask;
  late final AddCommentUseCase addComment;

  Future<void> close() => db.close();

  int _n = 0;

  Future<int> user([String? name]) async {
    _n++;
    final r = await createUser(name: name ?? 'User $_n', email: 'u$_n@mail.com');
    return r.value;
  }

  Future<int> project(String name, {int? ownerId}) async =>
      (await createProject(name: name, ownerId: ownerId)).value;

  /// Задача по id (в том числе из корзины).
  Future<Task?> task(int id) async =>
      (await tasks.watchTask(id).first).value?.task;

  /// История задачи от старых записей к новым.
  Future<List<HistoryEntry>> history(int taskId) async {
    final items = (await tasks.watchHistory(taskId).first).value;
    return items.reversed.map((e) => e.entry).toList();
  }

  Future<List<TaskItem>> list(TaskFilter filter) async =>
      (await tasks.getTasks(filter)).value;
}
