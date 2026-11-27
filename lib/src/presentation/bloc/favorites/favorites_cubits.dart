import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/usecases/favorites_usecases.dart';
import '../common/watch_cubit.dart';

class FavoritesState extends Equatable {
  const FavoritesState(this.ids);
  final Set<int> ids;

  bool contains(int taskId) => ids.contains(taskId);

  @override
  List<Object?> get props => [ids];
}

/// Глобальный набор избранных задач (для звёздочек в списках и карточке).
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(WatchFavoriteIdsUseCase watchIds, this._toggle)
    : super(const FavoritesState({})) {
    _subscription = watchIds().listen((result) {
      result.fold((_) {}, (ids) {
        if (!isClosed) emit(FavoritesState(ids));
      });
    });
  }

  final ToggleFavoriteUseCase _toggle;
  StreamSubscription<Either<Failure, Set<int>>>? _subscription;

  Future<Either<Failure, bool>> toggle(int taskId) => _toggle(taskId);

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

/// Экран «Избранное».
class FavoriteTasksCubit extends WatchCubit<List<TaskItem>> {
  FavoriteTasksCubit(this._watchFavoriteTasks);
  final WatchFavoriteTasksUseCase _watchFavoriteTasks;

  @override
  Stream<Either<Failure, List<TaskItem>>> watch() => _watchFavoriteTasks();
}
