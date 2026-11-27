import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/enums.dart';
import '../entities/history.dart';
import '../entities/task.dart';

abstract class TaskRepository {
  Stream<Either<Failure, List<TaskItem>>> watchTasks(TaskFilter filter);
  Future<Either<Failure, List<TaskItem>>> getTasks(TaskFilter filter);
  Stream<Either<Failure, TaskItem?>> watchTask(int id);

  Stream<Either<Failure, List<HistoryItem>>> watchHistory(int taskId);

  /// Последняя запись истории, которую можно отменить (смена статуса).
  Stream<Either<Failure, HistoryEntry?>> watchLastUndoable(int taskId);

  Future<Either<Failure, int>> createTask({
    required String title,
    String description = '',
    required int projectId,
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? deadline,
    int? actorId,
  });

  Future<Either<Failure, Unit>> updateTask(
    int id, {
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  });

  Future<Either<Failure, Unit>> changePriority(int id, TaskPriority priority);

  Future<Either<Failure, Unit>> changeStatus(
    int id,
    TaskStatus status, {
    int? actorId,
  });

  Future<Either<Failure, Unit>> assignTask(
    int id,
    int? assigneeId, {
    int? actorId,
  });

  Future<Either<Failure, Unit>> undoLastStatusChange(
    int taskId, {
    int? actorId,
  });

  Future<Either<Failure, Unit>> softDelete(int id);
  Future<Either<Failure, Unit>> restore(int id);

  /// Физическое удаление (только из корзины).
  Future<Either<Failure, Unit>> deleteForever(int id);
}
