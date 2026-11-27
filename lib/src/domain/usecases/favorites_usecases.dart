import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../../core/utils/stream_extensions.dart';
import '../entities/task.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/task_repository.dart';

class WatchFavoriteIdsUseCase {
  const WatchFavoriteIdsUseCase(this._repository);
  final FavoritesRepository _repository;

  Stream<Either<Failure, Set<int>>> call() => _repository.watchFavoriteIds();
}

class ToggleFavoriteUseCase {
  const ToggleFavoriteUseCase(this._repository);
  final FavoritesRepository _repository;

  Future<Either<Failure, bool>> call(int taskId) =>
      _repository.toggleFavorite(taskId);
}

/// Избранные задачи: id берутся из локального хранилища, сами задачи — из БД.
/// Список обновляется и при изменении избранного, и при изменении задач.
class WatchFavoriteTasksUseCase {
  const WatchFavoriteTasksUseCase(this._favorites, this._tasks);
  final FavoritesRepository _favorites;
  final TaskRepository _tasks;

  Stream<Either<Failure, List<TaskItem>>> call() {
    return _favorites.watchFavoriteIds().switchMap((idsResult) {
      return idsResult.fold<Stream<Either<Failure, List<TaskItem>>>>(
        (failure) => Stream.value(Left(failure)),
        (ids) {
          if (ids.isEmpty) {
            return Stream.value(const Right<Failure, List<TaskItem>>([]));
          }
          return _tasks.watchTasks(TaskFilter(taskIds: ids));
        },
      );
    });
  }
}
