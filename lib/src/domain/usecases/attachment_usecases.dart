import 'dart:typed_data';

import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/attachment.dart';
import '../repositories/attachment_repository.dart';
import '../validators/validators.dart';

class WatchAttachmentsUseCase {
  const WatchAttachmentsUseCase(this._repository);
  final AttachmentRepository _repository;

  Stream<Either<Failure, List<Attachment>>> call(int taskId) =>
      _repository.watchAttachments(taskId);
}

class AddAttachmentUseCase {
  const AddAttachmentUseCase(this._repository);
  final AttachmentRepository _repository;

  Future<Either<Failure, int>> call({
    required int taskId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final failure = Validators.fileName(fileName);
    if (failure != null) return Left(failure);
    return _repository.addAttachment(
      taskId: taskId,
      fileName: fileName.trim(),
      bytes: bytes,
    );
  }
}

class DeleteAttachmentUseCase {
  const DeleteAttachmentUseCase(this._repository);
  final AttachmentRepository _repository;

  Future<Either<Failure, Unit>> call(int id) => _repository.deleteAttachment(id);
}
