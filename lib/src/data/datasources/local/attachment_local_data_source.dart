import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../models/app_database.dart';

abstract class AttachmentLocalDataSource {
  Stream<List<AttachmentRow>> watchAttachments(int taskId);
  Future<List<AttachmentRow>> getAttachments(int taskId);
  Future<int> addAttachment({
    required int taskId,
    required String fileName,
    required Uint8List bytes,
  });
  Future<void> deleteAttachment(int id);
}

class AttachmentLocalDataSourceImpl implements AttachmentLocalDataSource {
  AttachmentLocalDataSourceImpl(
    this._db, {
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final AppDatabase _db;
  final Future<Directory> Function() _documentsDirectory;

  @override
  Stream<List<AttachmentRow>> watchAttachments(int taskId) =>
      (_db.select(_db.attachments)
            ..where((a) => a.taskId.equals(taskId))
            ..orderBy([(a) => OrderingTerm.desc(a.addedAt)]))
          .watch();

  @override
  Future<List<AttachmentRow>> getAttachments(int taskId) => (_db.select(
    _db.attachments,
  )..where((a) => a.taskId.equals(taskId))).get();

  /// Файл копируется в папку приложения, в БД хранится только путь.
  @override
  Future<int> addAttachment({
    required int taskId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final task = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(taskId))).getSingleOrNull();
    if (task == null) throw const ValidationException('Задача не найдена');

    final docs = await _documentsDirectory();
    final dir = Directory(p.join(docs.path, 'attachments', '$taskId'));
    await dir.create(recursive: true);
    final target = File(
      p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_$fileName'),
    );
    await target.writeAsBytes(bytes);
    try {
      return await _db
          .into(_db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              fileName: fileName,
              filePath: target.path,
              taskId: taskId,
              addedAt: Value(DateTime.now()),
            ),
          );
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  @override
  Future<void> deleteAttachment(int id) async {
    final row = await (_db.select(
      _db.attachments,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.attachments)..where((a) => a.id.equals(id))).go();
    final file = File(row.filePath);
    if (await file.exists()) await file.delete();
  }
}
