import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/enums.dart';
import '../entities/history.dart';
import '../entities/task.dart';
import '../repositories/task_repository.dart';
import '../validators/validators.dart';

class WatchTasksUseCase {
  const WatchTasksUseCase(this._repository);
  final TaskRepository _repository;

  Stream<Either<Failure, List<TaskItem>>> call(TaskFilter filter) =>
      _repository.watchTasks(filter);
}

class GetTasksUseCase {
  const GetTasksUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, List<TaskItem>>> call(TaskFilter filter) =>
      _repository.getTasks(filter);
}

class WatchTaskUseCase {
  const WatchTaskUseCase(this._repository);
  final TaskRepository _repository;

  Stream<Either<Failure, TaskItem?>> call(int id) => _repository.watchTask(id);
}

class WatchTaskHistoryUseCase {
  const WatchTaskHistoryUseCase(this._repository);
  final TaskRepository _repository;

  Stream<Either<Failure, List<HistoryItem>>> call(int taskId) =>
      _repository.watchHistory(taskId);
}

class WatchLastUndoableUseCase {
  const WatchLastUndoableUseCase(this._repository);
  final TaskRepository _repository;

  Stream<Either<Failure, HistoryEntry?>> call(int taskId) =>
      _repository.watchLastUndoable(taskId);
}

/// Создание задачи и первая запись истории выполняются атомарно.
class CreateTaskUseCase {
  const CreateTaskUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, int>> call({
    required String title,
    String description = '',
    required int? projectId,
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? deadline,
    int? actorId,
  }) async {
    final failure = Validators.taskTitle(title);
    if (failure != null) return Left(failure);
    if (projectId == null) return const Left(ValidationFailure('Выберите проект'));
    return _repository.createTask(
      title: title.trim(),
      description: description.trim(),
      projectId: projectId,
      assigneeId: assigneeId,
      priority: priority,
      status: status,
      deadline: deadline,
      actorId: actorId,
    );
  }
}

class UpdateTaskUseCase {
  const UpdateTaskUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, Unit>> call(
    int id, {
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) async {
    final failure = Validators.taskTitle(title);
    if (failure != null) return Left(failure);
    return _repository.updateTask(
      id,
      title: title.trim(),
      description: description.trim(),
      priority: priority,
      deadline: deadline,
    );
  }
}

class ChangeTaskPriorityUseCase {
  const ChangeTaskPriorityUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, Unit>> call(int id, TaskPriority priority) =>
      _repository.changePriority(id, priority);
}

class ChangeTaskStatusUseCase {
  const ChangeTaskStatusUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, Unit>> call(
    int id,
    TaskStatus status, {
    int? actorId,
  }) => _repository.changeStatus(id, status, actorId: actorId);
}

class AssignTaskUseCase {
  const AssignTaskUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, Unit>> call(
    int id,
    int? assigneeId, {
    int? actorId,
  }) => _repository.assignTask(id, assigneeId, actorId: actorId);
}

class UndoStatusChangeUseCase {
  const UndoStatusChangeUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, Unit>> call(int taskId, {int? actorId}) =>
      _repository.undoLastStatusChange(taskId, actorId: actorId);
}

class SoftDeleteTaskUseCase {
  const SoftDeleteTaskUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, Unit>> call(int id) => _repository.softDelete(id);
}

class RestoreTaskUseCase {
  const RestoreTaskUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, Unit>> call(int id) => _repository.restore(id);
}

class DeleteTaskForeverUseCase {
  const DeleteTaskForeverUseCase(this._repository);
  final TaskRepository _repository;

  Future<Either<Failure, Unit>> call(int id) => _repository.deleteForever(id);
}
