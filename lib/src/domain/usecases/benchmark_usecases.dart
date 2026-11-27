import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/benchmark.dart';
import '../repositories/benchmark_repository.dart';

class RunBenchmarkUseCase {
  const RunBenchmarkUseCase(this._repository);
  final BenchmarkRepository _repository;

  Future<Either<Failure, BenchmarkReport>> call() => _repository.run();
}
