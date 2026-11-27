import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/usecases/task_usecases.dart';
import '../common/view_state.dart';

class TaskListState extends Equatable {
  const TaskListState({
    required this.filter,
    required this.pages,
    required this.pageSize,
    required this.view,
  });

  final TaskFilter filter;
  final int pages;
  final int pageSize;
  final ViewState<List<TaskItem>> view;

  /// Сколько задач запрашивается сейчас (пагинация «Загрузить ещё»).
  int get limit => pageSize * pages;

  /// Есть ли смысл показывать «Загрузить ещё».
  bool get hasMore => switch (view) {
    ViewSuccess<List<TaskItem>>(:final data) => data.length >= limit,
    _ => false,
  };

  TaskListState copyWith({
    TaskFilter? filter,
    int? pages,
    ViewState<List<TaskItem>>? view,
  }) => TaskListState(
    filter: filter ?? this.filter,
    pages: pages ?? this.pages,
    pageSize: pageSize,
    view: view ?? this.view,
  );

  @override
  List<Object?> get props => [filter, pages, pageSize, view];
}

/// Список задач: поиск, фильтры, сортировка и пагинация.
/// Данные приходят потоком и обновляются автоматически. Повторный запрос
/// не выполняется, если параметры фильтра не изменились.
class TaskListCubit extends Cubit<TaskListState> {
  TaskListCubit(
    this._watchTasks, {
    TaskFilter initialFilter = const TaskFilter(),
    int pageSize = AppConstants.taskPageSize,
  }) : super(
         TaskListState(
           filter: initialFilter,
           pages: 1,
           pageSize: pageSize,
           view: ViewInitial<List<TaskItem>>(),
         ),
       );

  final WatchTasksUseCase _watchTasks;
  StreamSubscription<Either<Failure, List<TaskItem>>>? _subscription;

  void load() => _subscribe();

  void retry() => _subscribe();

  void _subscribe() {
    _subscription?.cancel();
    // Пока есть старые данные, показываем их (без «мигания» индикатора).
    final hasData = state.view is ViewSuccess || state.view is ViewEmpty;
    if (!hasData) emit(state.copyWith(view: ViewLoading<List<TaskItem>>()));
    final query = state.filter.copyWith(limit: state.limit, offset: 0);
    _subscription = _watchTasks(query).listen((result) {
      if (isClosed) return;
      result.fold(
        (failure) => emit(state.copyWith(view: ViewError<List<TaskItem>>(failure))),
        (items) => emit(
          state.copyWith(
            view: items.isEmpty
                ? ViewEmpty<List<TaskItem>>()
                : ViewSuccess<List<TaskItem>>(items),
          ),
        ),
      );
    });
  }

  void _update(TaskFilter filter) {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter, pages: 1));
    _subscribe();
  }

  void setQuery(String q) => _update(state.filter.copyWith(query: q));
  void setStatus(TaskStatus? s) => _update(state.filter.copyWith(status: s));
  void setPriority(TaskPriority? p) =>
      _update(state.filter.copyWith(priority: p));
  void setAssignee(int? id) => _update(state.filter.copyWith(assigneeId: id));
  void setSort(TaskSort s) => _update(state.filter.copyWith(sort: s));
  void toggleDirection() =>
      _update(state.filter.copyWith(ascending: !state.filter.ascending));

  void loadMore() {
    if (!state.hasMore) return;
    emit(state.copyWith(pages: state.pages + 1));
    _subscribe();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
