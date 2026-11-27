import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../../domain/entities/stats.dart';
import '../../../domain/usecases/stats_usecases.dart';
import '../common/watch_cubit.dart';

class DashboardCubit extends WatchCubit<DashboardStats> {
  DashboardCubit(this._watchStats);
  final WatchDashboardStatsUseCase _watchStats;

  @override
  Stream<Either<Failure, DashboardStats>> watch() => _watchStats();
}
