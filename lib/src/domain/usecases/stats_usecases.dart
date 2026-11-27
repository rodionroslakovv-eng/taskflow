import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/stats.dart';
import '../repositories/stats_repository.dart';

class WatchDashboardStatsUseCase {
  const WatchDashboardStatsUseCase(this._repository);
  final StatsRepository _repository;

  Stream<Either<Failure, DashboardStats>> call() => _repository.watchStats();
}

class GetDashboardStatsUseCase {
  const GetDashboardStatsUseCase(this._repository);
  final StatsRepository _repository;

  Future<Either<Failure, DashboardStats>> call() => _repository.getStats();
}
