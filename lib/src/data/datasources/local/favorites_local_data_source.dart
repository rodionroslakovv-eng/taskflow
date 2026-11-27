import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../constants/app_constants.dart';

/// Локальное хранилище избранных задач (список id в SharedPreferences).
abstract class FavoritesLocalDataSource {
  Set<int> getIds();
  Stream<Set<int>> watchIds();

  /// Возвращает `true`, если задача стала избранной.
  Future<bool> toggle(int taskId);
}

class FavoritesLocalDataSourceImpl implements FavoritesLocalDataSource {
  FavoritesLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;
  final StreamController<Set<int>> _changes =
      StreamController<Set<int>>.broadcast();

  @override
  Set<int> getIds() {
    final raw = _prefs.getStringList(AppConstants.favoritesPreferencesKey);
    if (raw == null) return <int>{};
    return raw.map(int.tryParse).whereType<int>().toSet();
  }

  @override
  Stream<Set<int>> watchIds() async* {
    yield getIds();
    yield* _changes.stream;
  }

  @override
  Future<bool> toggle(int taskId) async {
    final ids = getIds();
    final added = ids.add(taskId);
    if (!added) ids.remove(taskId);
    final saved = await _prefs.setStringList(
      AppConstants.favoritesPreferencesKey,
      (ids.toList()..sort()).map((e) => '$e').toList(),
    );
    if (!saved) {
      throw StateError('Не удалось сохранить избранное');
    }
    _changes.add(ids);
    return added;
  }
}
