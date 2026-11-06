import 'package:drift/drift.dart';

import '../models/enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Projects,
    ProjectMembers,
    Tasks,
    Comments,
    Attachments,
    TaskHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// v1 — без tasks.priority; v2 — добавлено priority (по умолчанию medium).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // ALTER TABLE ... ADD COLUMN priority INTEGER NOT NULL DEFAULT 1
        // Все существующие строки получают medium, данные не теряются.
        await m.addColumn(tasks, tasks.priority);
        await m.createIndex(idxTasksPriority);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
