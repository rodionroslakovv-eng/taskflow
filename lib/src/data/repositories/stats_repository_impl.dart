import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/stats.dart';
import '../../domain/repositories/stats_repository.dart';
import '../datasources/local/stats_local_data_source.dart';
import '../mapper/mappers.dart';

class StatsRepositoryImpl implements StatsRepository {
  StatsRepositoryImpl(this._local);
  final StatsLocalDataSource _local;

  @override
  Future<Either<Failure, DashboardStats>> getStats() =>
      guardCall(() async => (await _local.getStats()).toEntity());

  @override
  Stream<Either<Failure, DashboardStats>> watchStats() =>
      guardStream(_local.watchStats().map((m) => m.toEntity()));
}
