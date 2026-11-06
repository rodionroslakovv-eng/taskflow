import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/models/enums.dart';

/// Схема v1: таблица tasks БЕЗ поля priority.
void _createV1(sql.Database raw) {
  raw.execute('''
    CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE, registered_at INTEGER NOT NULL DEFAULT (strftime('%s','now')));
    CREATE TABLE projects (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      finished_at INTEGER NULL, status TEXT NOT NULL DEFAULT 'active');
    CREATE TABLE project_members (id INTEGER PRIMARY KEY AUTOINCREMENT,
      project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role TEXT NOT NULL, joined_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      UNIQUE (project_id, user_id));
    CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      assignee_id INTEGER NULL REFERENCES users(id) ON DELETE SET NULL,
      status TEXT NOT NULL DEFAULT 'todo', deadline INTEGER NULL,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      deleted_at INTEGER NULL);
    CREATE TABLE comments (id INTEGER PRIMARY KEY AUTOINCREMENT, body TEXT NOT NULL,
      author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')));
    CREATE TABLE attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, file_name TEXT NOT NULL,
      file_path TEXT NOT NULL, task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      added_at INTEGER NOT NULL DEFAULT (strftime('%s','now')));
    CREATE TABLE task_history (id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      kind TEXT NOT NULL, old_status TEXT NULL, new_status TEXT NOT NULL,
      changed_by INTEGER NULL REFERENCES users(id) ON DELETE SET NULL,
      changed_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
      note TEXT NULL, undone INTEGER NOT NULL DEFAULT 0);
  ''');
}

void main() {
  test(
    'миграция v1 → v2: priority=medium у старых задач, данные целы',
    () async {
      final raw = sql.sqlite3.openInMemory();
      _createV1(raw);
      raw.execute(
        "INSERT INTO users (name,email) VALUES ('Old','old@mail.com')",
      );
      raw.execute("INSERT INTO projects (name) VALUES ('Legacy')");
      raw.execute(
        "INSERT INTO tasks (title,project_id,assignee_id,status) VALUES "
        "('t1',1,1,'todo'),('t2',1,1,'done'),('t3',1,NULL,'inProgress')",
      );
      raw.execute(
        "INSERT INTO comments (body,author_id,task_id) VALUES ('c',1,1)",
      );
      raw.execute('PRAGMA user_version = 1');

      final db = AppDatabase(NativeDatabase.opened(raw));
      addTearDown(db.close);

      final tasks = await db.select(db.tasks).get();
      expect(tasks, hasLength(3));
      expect(tasks.map((t) => t.priority), everyElement(TaskPriority.medium));
      expect(tasks.map((t) => t.title), containsAll(['t1', 't2', 't3']));
      expect(tasks.firstWhere((t) => t.title == 't2').status, TaskStatus.done);

      // остальные данные сохранились
      expect(await db.select(db.users).get(), hasLength(1));
      expect(await db.select(db.comments).get(), hasLength(1));

      // версия обновлена, новое поле работает
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 2);
      final cols = await db.customSelect("PRAGMA table_info('tasks')").get();
      expect(cols.map((c) => c.read<String>('name')), contains('priority'));
    },
  );

  test('новая БД создаётся сразу со схемой v2', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 2);
  });
}
