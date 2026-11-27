import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/comment.dart';
import '../repositories/comment_repository.dart';
import '../validators/validators.dart';

class WatchCommentsUseCase {
  const WatchCommentsUseCase(this._repository);
  final CommentRepository _repository;

  Stream<Either<Failure, List<CommentItem>>> call(int taskId) =>
      _repository.watchComments(taskId);
}

class AddCommentUseCase {
  const AddCommentUseCase(this._repository);
  final CommentRepository _repository;

  Future<Either<Failure, int>> call({
    required int taskId,
    required int? authorId,
    required String body,
  }) async {
    if (authorId == null) {
      return const Left(ValidationFailure('Выберите текущего пользователя'));
    }
    final failure = Validators.commentBody(body);
    if (failure != null) return Left(failure);
    return _repository.addComment(
      taskId: taskId,
      authorId: authorId,
      body: body.trim(),
    );
  }
}

class DeleteCommentUseCase {
  const DeleteCommentUseCase(this._repository);
  final CommentRepository _repository;

  Future<Either<Failure, Unit>> call(int commentId, {required int requesterId}) =>
      _repository.deleteComment(commentId, requesterId: requesterId);
}
