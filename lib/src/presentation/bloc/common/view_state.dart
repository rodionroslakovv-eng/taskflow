import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';

/// Общий набор состояний экрана: Initial → Loading → Success / Empty / Error.
sealed class ViewState<T> extends Equatable {
  const ViewState();

  @override
  List<Object?> get props => const [];
}

final class ViewInitial<T> extends ViewState<T> {
  const ViewInitial();
}

final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

final class ViewSuccess<T> extends ViewState<T> {
  const ViewSuccess(this.data);
  final T data;

  @override
  List<Object?> get props => [data];
}

/// Запрос выполнен успешно, но данных нет.
final class ViewEmpty<T> extends ViewState<T> {
  const ViewEmpty();
}

final class ViewError<T> extends ViewState<T> {
  const ViewError(this.failure);
  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
