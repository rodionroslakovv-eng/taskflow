import 'dart:typed_data';

import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/repositories/attachment_repository.dart';
import '../datasources/local/attachment_local_data_source.dart';
import '../mapper/mappers.dart';

class AttachmentRepositoryImpl implements AttachmentRepository {
  AttachmentRepositoryImpl(this._local);
  final AttachmentLocalDataSource _local;

  @override
  Stream<Either<Failure, List<Attachment>>> watchAttachments(int taskId) =>
      guardStream(
        _local
            .watchAttachments(taskId)
            .map((rows) => rows.map((r) => r.toEntity()).toList()),
      );

  @override
  Future<Either<Failure, List<Attachment>>> getAttachments(int taskId) =>
      guardCall(() async {
        final rows = await _local.getAttachments(taskId);
        return rows.map((r) => r.toEntity()).toList();
      });

  @override
  Future<Either<Failure, int>> addAttachment({
    required int taskId,
    required String fileName,
    required Uint8List bytes,
  }) => guardCall(
    () => _local.addAttachment(taskId: taskId, fileName: fileName, bytes: bytes),
  );

  @override
  Future<Either<Failure, Unit>> deleteAttachment(int id) => guardCall(() async {
    await _local.deleteAttachment(id);
    return unit;
  });
}
