import 'package:drift/drift.dart';

import '../models/enums.dart';

@DataClassName('UserRow')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().unique()();
  DateTimeColumn get registeredAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ProjectRow')
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get status => textEnum<ProjectStatus>().withDefault(
    Constant(ProjectStatus.active.name),
  )();
}

/// Связь many-to-many между users и projects.
@DataClassName('MemberRow')
class ProjectMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get userId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => textEnum<MemberRole>()();
  DateTimeColumn get joinedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {projectId, userId},
  ];
}

@DataClassName('TaskRow')
@TableIndex(name: 'idx_tasks_project', columns: {#projectId})
@TableIndex(name: 'idx_tasks_assignee', columns: {#assigneeId})
@TableIndex(name: 'idx_tasks_status', columns: {#status})
@TableIndex(name: 'idx_tasks_priority', columns: {#priority})
@TableIndex(name: 'idx_tasks_deadline', columns: {#deadline})
@TableIndex(name: 'idx_tasks_created', columns: {#createdAt})
@TableIndex(
  name: 'idx_tasks_assignee_deadline',
  columns: {#assigneeId, #deadline},
)
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get assigneeId => integer().nullable().references(
    Users,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Добавлено в схеме v2. Для старых задач миграция ставит medium (индекс 1).
  IntColumn get priority =>
      intEnum<TaskPriority>().withDefault(const Constant(1))();
  TextColumn get status =>
      textEnum<TaskStatus>().withDefault(Constant(TaskStatus.todo.name))();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// Soft delete: если не null — задача в корзине.
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DataClassName('CommentRow')
@TableIndex(name: 'idx_comments_task', columns: {#taskId})
class Comments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text().withLength(min: 1, max: 2000)();
  IntColumn get authorId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('AttachmentRow')
@TableIndex(name: 'idx_attachments_task', columns: {#taskId})
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text()();

  /// В БД хранится только путь к файлу, не содержимое.
  TextColumn get filePath => text()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('HistoryRow')
@TableIndex(name: 'idx_history_task', columns: {#taskId})
class TaskHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<HistoryKind>()();

  /// null для записи о создании задачи.
  TextColumn get oldStatus => textEnum<TaskStatus>().nullable()();
  TextColumn get newStatus => textEnum<TaskStatus>()();
  IntColumn get changedBy => integer().nullable().references(
    Users,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();

  /// Запись уже отменена через Undo.
  BoolColumn get undone => boolean().withDefault(const Constant(false))();
}
