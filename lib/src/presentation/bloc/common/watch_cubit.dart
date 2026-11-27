import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import 'view_state.dart';

/// Базовый Cubit для экранов, которые следят за потоком данных из UseCase.
/// Поддерживает повторную загрузку ([retry]) и не создаёт лишних подписок.
abstract class WatchCubit<T> extends Cubit<ViewState<T>> {
  WatchCubit() : super(ViewInitial<T>());

  StreamSubscription<Either<Failure, T>>? _subscription;

  /// Поток результатов UseCase.
  Stream<Either<Failure, T>> watch();

  /// Какие данные считать «пустыми» (по умолчанию: пустой список или null).
  bool isEmptyData(T data) => data is Iterable ? data.isEmpty : data == null;

  /// Подписывается на данные. Вызывается один раз при создании Cubit.
  void load() {
    _subscription?.cancel();
    emit(ViewLoading<T>());
    _subscription = watch().listen(_onResult);
  }

  /// Повторная загрузка после ошибки.
  void retry() => load();

  void _onResult(Either<Failure, T> result) {
    if (isClosed) return;
    result.fold(
      (failure) => emit(ViewError<T>(failure)),
      (data) =>
          emit(isEmptyData(data) ? ViewEmpty<T>() : ViewSuccess<T>(data)),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
