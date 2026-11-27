abstract final class AppConstants {
  static const String appTitle = 'TaskFlow';
  static const String databaseFileName = 'taskflow.sqlite';
  static const String benchmarkDatabaseFileName = 'taskflow_perf.sqlite';
  static const String favoritesPreferencesKey = 'favorite_task_ids';

  /// Размер страницы списка задач.
  static const int taskPageSize = 20;

  /// Максимум пользователей в выпадающих списках.
  static const int maxUsersInMenu = 50;
}
