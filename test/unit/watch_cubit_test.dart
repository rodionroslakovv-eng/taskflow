import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/core/utils/either.dart';
import 'package:taskflow/src/presentation/bloc/common/view_state.dart';
import 'package:taskflow/src/presentation/bloc/common/watch_cubit.dart';

class _TestCubit extends WatchCubit<List<int>> {
  final controllers = <StreamController<Either<Failure, List<int>>>>[];

  @override
  Stream<Either<Failure, List<int>>> watch() {
    final c = StreamController<Either<Failure, List<int>>>();
    controllers.add(c);
    return c.stream;
  }
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('Loading → Success → Empty → Error, затем retry → Loading → Success', () async {
    final cubit = _TestCubit();
    final states = <ViewState<List<int>>>[];
    final sub = cubit.stream.listen(states.add);

    expect(cubit.state, isA<ViewInitial<List<int>>>());
    cubit.load();
    cubit.controllers.last.add(const Right([1, 2]));
    await _tick();
    cubit.controllers.last.add(const Right([]));
    await _tick();
    cubit.controllers.last.add(const Left(NetworkFailure()));
    await _tick();

    cubit.retry();
    cubit.controllers.last.add(const Right([3]));
    await _tick();

    expect(states, [
      const ViewLoading<List<int>>(),
      const ViewSuccess<List<int>>([1, 2]),
      const ViewEmpty<List<int>>(),
      const ViewError<List<int>>(NetworkFailure()),
      const ViewLoading<List<int>>(),
      const ViewSuccess<List<int>>([3]),
    ]);

    await sub.cancel();
    await cubit.close();
  });
}
