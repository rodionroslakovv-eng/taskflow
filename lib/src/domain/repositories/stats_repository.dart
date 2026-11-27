import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/stats.dart';

abstract class StatsRepository {
  Future<Either<Failure, DashboardStats>> getStats();

  /// Статистика пересчитывается при любом изменении задач/проектов/пользователей.
  Stream<Either<Failure, DashboardStats>> watchStats();
}
