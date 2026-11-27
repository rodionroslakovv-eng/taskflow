import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../core/error/failure_message.dart';
import '../bloc/common/view_state.dart';
import '../bloc/common/watch_cubit.dart';

/// Единообразно рисует состояния Loading / Empty / Error (с «Повторить»)
/// и передаёт данные в [builder] только в состоянии Success.
class ViewStateBuilder<B extends WatchCubit<T>, T> extends StatelessWidget {
  const ViewStateBuilder({
    super.key,
    required this.builder,
    this.emptyText = 'Нет данных',
    this.emptyBuilder,
  });

  final Widget Function(BuildContext context, T data) builder;
  final String emptyText;

  /// Если задан — используется вместо [emptyText].
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<B, ViewState<T>>(
      builder: (context, state) => switch (state) {
        ViewInitial<T>() || ViewLoading<T>() => const LoadingView(),
        ViewEmpty<T>() =>
          emptyBuilder != null ? emptyBuilder!(context) : EmptyState(emptyText),
        ViewError<T>(:final failure) => ErrorView(
          message: failureMessage(failure),
          onRetry: () => context.read<B>().retry(),
        ),
        ViewSuccess<T>(:final data) => builder(context, data),
      },
    );
  }
}
