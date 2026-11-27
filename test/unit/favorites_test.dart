import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/src/data/datasources/local/favorites_local_data_source.dart';
import 'package:taskflow/src/data/repositories/favorites_repository_impl.dart';
import 'package:taskflow/src/domain/usecases/favorites_usecases.dart';

import '../helpers.dart';

void main() {
  late TestEnv env;
  late FavoritesRepositoryImpl favorites;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    env = TestEnv();
    favorites = FavoritesRepositoryImpl(FavoritesLocalDataSourceImpl(prefs));
  });
  tearDown(() => env.close());

  test('toggle добавляет и убирает задачу из избранного', () async {
    final toggle = ToggleFavoriteUseCase(favorites);
    expect((await toggle(5)).value, isTrue);
    expect((await favorites.watchFavoriteIds().first).value, {5});
    expect((await toggle(5)).value, isFalse);
    expect((await favorites.watchFavoriteIds().first).value, isEmpty);
  });

  test('избранное переживает пересоздание хранилища', () async {
    await ToggleFavoriteUseCase(favorites)(7);
    final prefs = await SharedPreferences.getInstance();
    final again = FavoritesRepositoryImpl(FavoritesLocalDataSourceImpl(prefs));
    expect((await again.watchFavoriteIds().first).value, {7});
  });

  test('WatchFavoriteTasks отдаёт только избранные задачи', () async {
    final p = await env.project('P');
    final a = (await env.createTask(title: 'A', projectId: p)).value;
    (await env.createTask(title: 'B', projectId: p)).value;

    final watch = WatchFavoriteTasksUseCase(favorites, env.tasks);
    expect((await watch().first).value, isEmpty);

    await ToggleFavoriteUseCase(favorites)(a);
    final list = (await watch().first).value;
    expect(list.map((e) => e.task.title), ['A']);
  });
}
