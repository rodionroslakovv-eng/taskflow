import 'dart:typed_data';

import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/attachment.dart';

abstract class AttachmentRepository {
  Stream<Either<Failure, List<Attachment>>> watchAttachments(int taskId);
  Future<Either<Failure, List<Attachment>>> getAttachments(int taskId);

  /// Сохраняет содержимое файла в хранилище приложения; в БД попадает путь.
  Future<Either<Failure, int>> addAttachment({
    required int taskId,
    required String fileName,
    required Uint8List bytes,
  });

  Future<Either<Failure, Unit>> deleteAttachment(int id);
}
