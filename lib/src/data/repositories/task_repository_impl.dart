import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/task_local_data_source.dart';
import '../mapper/mappers.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl(this._local);
  final TaskLocalDataSource _local;

  @override
  Stream<Either<Failure, List<TaskItem>>> watchTasks(TaskFilter filter) =>
      guardStream(
        _local
            .watchTasks(filter)
            .map((rows) => rows.map((r) => r.toEntity()).toList()),
      );

  @override
  Future<Either<Failure, List<TaskItem>>> getTasks(TaskFilter filter) =>
      guardCall(() async {
        final rows = await _local.getTasks(filter);
        return rows.map((r) => r.toEntity()).toList();
      });

  @override
  Stream<Either<Failure, TaskItem?>> watchTask(int id) =>
      guardStream(_local.watchTask(id).map((row) => row?.toEntity()));

  @override
  Stream<Either<Failure, List<HistoryItem>>> watchHistory(int taskId) =>
      guardStream(
        _local
            .watchHistory(taskId)
            .map((rows) => rows.map((r) => r.toEntity()).toList()),
      );

  @override
  Stream<Either<Failure, HistoryEntry?>> watchLastUndoable(int taskId) =>
      guardStream(_local.watchLastUndoable(taskId).map((r) => r?.toEntity()));

  @override
  Future<Either<Failure, int>> createTask({
    required String title,
    String description = '',
    required int projectId,
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? deadline,
    int? actorId,
  }) => guardCall(
    () => _local.createTask(
      title: title,
      description: description,
      projectId: projectId,
      assigneeId: assigneeId,
      priority: priority,
      status: status,
      deadline: deadline,
      actorId: actorId,
    ),
  );

  @override
  Future<Either<Failure, Unit>> updateTask(
    int id, {
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) => guardCall(() async {
    await _local.updateTask(
      id,
      title: title,
      description: description,
      priority: priority,
      deadline: deadline,
    );
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> changePriority(
    int id,
    TaskPriority priority,
  ) => guardCall(() async {
    await _local.changePriority(id, priority);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> changeStatus(
    int id,
    TaskStatus status, {
    int? actorId,
  }) => guardCall(() async {
    await _local.changeStatus(id, status, actorId: actorId);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> assignTask(
    int id,
    int? assigneeId, {
    int? actorId,
  }) => guardCall(() async {
    await _local.assignTask(id, assigneeId, actorId: actorId);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> undoLastStatusChange(
    int taskId, {
    int? actorId,
  }) => guardCall(() async {
    await _local.undoLastStatusChange(taskId, actorId: actorId);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> softDelete(int id) => guardCall(() async {
    await _local.softDelete(id);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> restore(int id) => guardCall(() async {
    await _local.restore(id);
    return unit;
  });

  @override
  Future<Either<Failure, Unit>> deleteForever(int id) => guardCall(() async {
    await _local.deleteForever(id);
    return unit;
  });
}
