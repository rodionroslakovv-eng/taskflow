import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/benchmark.dart';

abstract class BenchmarkRepository {
  /// Создаёт отдельную тестовую БД и сравнивает запросы с индексами и без.
  Future<Either<Failure, BenchmarkReport>> run();
}
