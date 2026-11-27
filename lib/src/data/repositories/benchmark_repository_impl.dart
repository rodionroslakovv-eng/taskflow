import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/benchmark.dart';
import '../../domain/repositories/benchmark_repository.dart';
import '../datasources/local/benchmark_local_data_source.dart';
import '../mapper/mappers.dart';

class BenchmarkRepositoryImpl implements BenchmarkRepository {
  BenchmarkRepositoryImpl(this._local);
  final BenchmarkLocalDataSource _local;

  @override
  Future<Either<Failure, BenchmarkReport>> run() =>
      guardCall(() async => (await _local.run()).toEntity());
}
