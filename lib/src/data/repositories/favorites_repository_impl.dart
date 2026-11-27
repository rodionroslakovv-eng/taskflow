import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/local/favorites_local_data_source.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._local);
  final FavoritesLocalDataSource _local;

  @override
  Stream<Either<Failure, Set<int>>> watchFavoriteIds() =>
      guardStream(_local.watchIds());

  @override
  Future<Either<Failure, bool>> toggleFavorite(int taskId) =>
      guardCall(() => _local.toggle(taskId));
}
