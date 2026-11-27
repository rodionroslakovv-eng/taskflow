import 'dart:io';

import 'package:drift/drift.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/app_database.dart';
import '../../src/data/datasources/local/attachment_local_data_source.dart';
import '../../src/data/datasources/local/benchmark_local_data_source.dart';
import '../../src/data/datasources/local/comment_local_data_source.dart';
import '../../src/data/datasources/local/database_connection.dart';
import '../../src/data/datasources/local/favorites_local_data_source.dart';
import '../../src/data/datasources/local/project_local_data_source.dart';
import '../../src/data/datasources/local/stats_local_data_source.dart';
import '../../src/data/datasources/local/task_local_data_source.dart';
import '../../src/data/datasources/local/user_local_data_source.dart';
import '../../src/data/repositories/attachment_repository_impl.dart';
import '../../src/data/repositories/benchmark_repository_impl.dart';
import '../../src/data/repositories/comment_repository_impl.dart';
import '../../src/data/repositories/favorites_repository_impl.dart';
import '../../src/data/repositories/project_repository_impl.dart';
import '../../src/data/repositories/stats_repository_impl.dart';
import '../../src/data/repositories/task_repository_impl.dart';
import '../../src/data/repositories/user_repository_impl.dart';
import '../../src/domain/entities/task.dart';
import '../../src/domain/repositories/attachment_repository.dart';
import '../../src/domain/repositories/benchmark_repository.dart';
import '../../src/domain/repositories/comment_repository.dart';
import '../../src/domain/repositories/favorites_repository.dart';
import '../../src/domain/repositories/project_repository.dart';
import '../../src/domain/repositories/stats_repository.dart';
import '../../src/domain/repositories/task_repository.dart';
import '../../src/domain/repositories/user_repository.dart';
import '../../src/domain/usecases/attachment_usecases.dart';
import '../../src/domain/usecases/benchmark_usecases.dart';
import '../../src/domain/usecases/comment_usecases.dart';
import '../../src/domain/usecases/favorites_usecases.dart';
import '../../src/domain/usecases/project_usecases.dart';
import '../../src/domain/usecases/stats_usecases.dart';
import '../../src/domain/usecases/task_usecases.dart';
import '../../src/domain/usecases/user_usecases.dart';
import '../../src/presentation/bloc/benchmark/benchmark_cubit.dart';
import '../../src/presentation/bloc/dashboard/dashboard_cubit.dart';
import '../../src/presentation/bloc/favorites/favorites_cubits.dart';
import '../../src/presentation/bloc/projects/projects_cubits.dart';
import '../../src/presentation/bloc/tasks/task_cubits.dart';
import '../../src/presentation/bloc/tasks/task_list_cubit.dart';
import '../../src/presentation/bloc/users/users_cubits.dart';

final GetIt getIt = GetIt.instance;

/// Единственное место, где создаются и связываются все зависимости.
///
/// Порядок регистрации (снизу вверх по слоям):
/// 1. инфраструктура (БД, SharedPreferences);
/// 2. DataSource → 3. Repository (реализация Data Layer под интерфейсом Domain);
/// 4. UseCase → 5. Cubit.
///
/// Параметры нужны только тестам: подмена БД, хранилища и папки документов.
Future<void> configureDependencies({
  QueryExecutor? executor,
  SharedPreferences? preferences,
  Future<Directory> Function()? documentsDirectory,
}) async {
  // ---- 1. Инфраструктура ----
  final prefs = preferences ?? await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  getIt.registerSingleton<AppDatabase>(
    AppDatabase(executor ?? openConnection()),
    dispose: (db) => db.close(),
  );

  // ---- 2. DataSources ----
  getIt
    ..registerLazySingleton<UserLocalDataSource>(
      () => UserLocalDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<ProjectLocalDataSource>(
      () => ProjectLocalDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<TaskLocalDataSource>(
      () => TaskLocalDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<CommentLocalDataSource>(
      () => CommentLocalDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<AttachmentLocalDataSource>(
      () => AttachmentLocalDataSourceImpl(
        getIt(),
        documentsDirectory: documentsDirectory,
      ),
    )
    ..registerLazySingleton<StatsLocalDataSource>(
      () => StatsLocalDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<FavoritesLocalDataSource>(
      () => FavoritesLocalDataSourceImpl(getIt()),
    )
    ..registerLazySingleton<BenchmarkLocalDataSource>(
      () => BenchmarkLocalDataSourceImpl(documentsDirectory: documentsDirectory),
    );

  // ---- 3. Repositories ----
  getIt
    ..registerLazySingleton<UserRepository>(() => UserRepositoryImpl(getIt()))
    ..registerLazySingleton<ProjectRepository>(
      () => ProjectRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(getIt()))
    ..registerLazySingleton<CommentRepository>(
      () => CommentRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<AttachmentRepository>(
      () => AttachmentRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<StatsRepository>(
      () => StatsRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<FavoritesRepository>(
      () => FavoritesRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<BenchmarkRepository>(
      () => BenchmarkRepositoryImpl(getIt()),
    );

  // ---- 4. UseCases ----
  getIt
    // users
    ..registerFactory(() => WatchUsersUseCase(getIt()))
    ..registerFactory(() => GetUsersUseCase(getIt()))
    ..registerFactory(() => WatchUserUseCase(getIt()))
    ..registerFactory(() => CreateUserUseCase(getIt()))
    ..registerFactory(() => UpdateUserUseCase(getIt()))
    ..registerFactory(() => DeleteUserUseCase(getIt()))
    // projects
    ..registerFactory(() => WatchProjectsUseCase(getIt()))
    ..registerFactory(() => GetProjectsUseCase(getIt()))
    ..registerFactory(() => WatchProjectUseCase(getIt()))
    ..registerFactory(() => CreateProjectUseCase(getIt()))
    ..registerFactory(() => UpdateProjectUseCase(getIt()))
    ..registerFactory(() => DeleteProjectUseCase(getIt()))
    ..registerFactory(() => WatchProjectMembersUseCase(getIt()))
    ..registerFactory(() => GetProjectMembersUseCase(getIt()))
    ..registerFactory(() => GetAddableUsersUseCase(getIt(), getIt()))
    ..registerFactory(() => AddProjectMemberUseCase(getIt()))
    ..registerFactory(() => RemoveProjectMemberUseCase(getIt()))
    ..registerFactory(() => SetMemberRoleUseCase(getIt()))
    // tasks
    ..registerFactory(() => WatchTasksUseCase(getIt()))
    ..registerFactory(() => GetTasksUseCase(getIt()))
    ..registerFactory(() => WatchTaskUseCase(getIt()))
    ..registerFactory(() => WatchTaskHistoryUseCase(getIt()))
    ..registerFactory(() => WatchLastUndoableUseCase(getIt()))
    ..registerFactory(() => CreateTaskUseCase(getIt()))
    ..registerFactory(() => UpdateTaskUseCase(getIt()))
    ..registerFactory(() => ChangeTaskPriorityUseCase(getIt()))
    ..registerFactory(() => ChangeTaskStatusUseCase(getIt()))
    ..registerFactory(() => AssignTaskUseCase(getIt()))
    ..registerFactory(() => UndoStatusChangeUseCase(getIt()))
    ..registerFactory(() => SoftDeleteTaskUseCase(getIt()))
    ..registerFactory(() => RestoreTaskUseCase(getIt()))
    ..registerFactory(() => DeleteTaskForeverUseCase(getIt()))
    // comments / attachments
    ..registerFactory(() => WatchCommentsUseCase(getIt()))
    ..registerFactory(() => AddCommentUseCase(getIt()))
    ..registerFactory(() => DeleteCommentUseCase(getIt()))
    ..registerFactory(() => WatchAttachmentsUseCase(getIt()))
    ..registerFactory(() => AddAttachmentUseCase(getIt()))
    ..registerFactory(() => DeleteAttachmentUseCase(getIt()))
    // stats, favorites, benchmark
    ..registerFactory(() => WatchDashboardStatsUseCase(getIt()))
    ..registerFactory(() => GetDashboardStatsUseCase(getIt()))
    ..registerFactory(() => WatchFavoriteIdsUseCase(getIt()))
    ..registerFactory(() => ToggleFavoriteUseCase(getIt()))
    ..registerFactory(() => WatchFavoriteTasksUseCase(getIt(), getIt()))
    ..registerFactory(() => RunBenchmarkUseCase(getIt()));

  // ---- 5. Cubits (каждый экран получает свой экземпляр) ----
  getIt
    ..registerFactory(
      () => UsersCubit(getIt(), getIt(), getIt(), getIt()),
    )
    ..registerFactory(() => CurrentUserCubit(getIt()))
    ..registerFactory(() => FavoritesCubit(getIt(), getIt()))
    ..registerFactory(() => FavoriteTasksCubit(getIt()))
    ..registerFactory(() => ProjectsCubit(getIt(), getIt()))
    ..registerFactory(() => TrashCubit(getIt(), getIt(), getIt()))
    ..registerFactory(() => DashboardCubit(getIt()))
    ..registerFactory(() => BenchmarkCubit(getIt()))
    ..registerFactory(
      () => TaskFormCubit(getIt(), getIt(), getIt(), getIt()),
    )
    // Cubit'ы с параметром (id или начальный фильтр).
    ..registerFactoryParam<TaskListCubit, TaskFilter, void>(
      (filter, _) =>
          TaskListCubit(getIt(), initialFilter: filter as TaskFilter),
    )
    ..registerFactoryParam<UserDetailCubit, int, void>(
      (id, _) => UserDetailCubit(id as int, getIt(), getIt()),
    )
    ..registerFactoryParam<ProjectDetailCubit, int, void>(
      (id, _) => ProjectDetailCubit(id as int, getIt(), getIt(), getIt()),
    )
    ..registerFactoryParam<ProjectMembersCubit, int, void>(
      (id, _) => ProjectMembersCubit(
        id as int,
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
      ),
    )
    ..registerFactoryParam<TaskDetailCubit, int, void>(
      (id, _) => TaskDetailCubit(
        id as int,
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
        getIt(),
      ),
    )
    ..registerFactoryParam<TaskHistoryCubit, int, void>(
      (id, _) => TaskHistoryCubit(id as int, getIt()),
    )
    ..registerFactoryParam<LastUndoableCubit, int, void>(
      (id, _) => LastUndoableCubit(id as int, getIt()),
    )
    ..registerFactoryParam<CommentsCubit, int, void>(
      (id, _) => CommentsCubit(id as int, getIt(), getIt(), getIt()),
    )
    ..registerFactoryParam<AttachmentsCubit, int, void>(
      (id, _) => AttachmentsCubit(id as int, getIt(), getIt(), getIt()),
    );
}

/// Сбрасывает контейнер (нужно тестам между запусками).
Future<void> resetDependencies() => getIt.reset();
