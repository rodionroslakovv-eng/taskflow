import 'package:equatable/equatable.dart';

class BenchmarkResult extends Equatable {
  const BenchmarkResult(this.name, this.withIndexMs, this.withoutIndexMs);

  final String name;
  final double withIndexMs;
  final double withoutIndexMs;

  double get speedup => withIndexMs == 0 ? 0 : withoutIndexMs / withIndexMs;

  @override
  List<Object?> get props => [name, withIndexMs, withoutIndexMs];
}

class BenchmarkReport extends Equatable {
  const BenchmarkReport({required this.seedMs, required this.results});

  /// За сколько миллисекунд создана тестовая БД.
  final int seedMs;
  final List<BenchmarkResult> results;

  @override
  List<Object?> get props => [seedMs, results];
}
