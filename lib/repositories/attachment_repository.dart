import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/models.dart';

class AttachmentRepository {
  AttachmentRepository(this._db);
  final AppDatabase _db;

  Stream<List<AttachmentRow>> watchAttachments(int taskId) =>
      (_db.select(_db.attachments)
            ..where((a) => a.taskId.equals(taskId))
            ..orderBy([(a) => OrderingTerm.desc(a.addedAt)]))
          .watch();

  Future<List<AttachmentRow>> getAttachments(int taskId) => (_db.select(
    _db.attachments,
  )..where((a) => a.taskId.equals(taskId))).get();

  /// Сохраняется только путь к файлу, не содержимое.
  Future<int> addAttachment({
    required int taskId,
    required String fileName,
    required String filePath,
  }) async {
    if (fileName.trim().isEmpty || filePath.trim().isEmpty) {
      throw TaskFlowException('Некорректный файл');
    }
    final task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) throw TaskFlowException('Задача не найдена');
    return _db
        .into(_db.attachments)
        .insert(
          AttachmentsCompanion.insert(
            fileName: fileName.trim(),
            filePath: filePath,
            taskId: taskId,
            addedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> deleteAttachment(int id) =>
      (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
}
