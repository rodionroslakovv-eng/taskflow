import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';

/// Избранные задачи (локальное хранение).
abstract class FavoritesRepository {
  Stream<Either<Failure, Set<int>>> watchFavoriteIds();

  /// Добавляет/убирает задачу из избранного. Возвращает новое состояние.
  Future<Either<Failure, bool>> toggleFavorite(int taskId);
}
