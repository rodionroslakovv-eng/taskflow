import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/benchmark.dart';
import '../../../domain/usecases/benchmark_usecases.dart';
import '../common/view_state.dart';

/// Initial — «не запускали», Loading — идёт замер, Success — отчёт готов.
class BenchmarkCubit extends Cubit<ViewState<BenchmarkReport>> {
  BenchmarkCubit(this._run) : super(ViewInitial<BenchmarkReport>());

  final RunBenchmarkUseCase _run;

  Future<void> run() async {
    if (state is ViewLoading) return; // не запускаем повторно
    emit(ViewLoading<BenchmarkReport>());
    final result = await _run();
    if (isClosed) return;
    emit(
      result.fold(
        (f) => ViewError<BenchmarkReport>(f),
        (report) => ViewSuccess<BenchmarkReport>(report),
      ),
    );
  }
}
