import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../entities/comment.dart';

abstract class CommentRepository {
  Stream<Either<Failure, List<CommentItem>>> watchComments(int taskId);
  Future<Either<Failure, List<CommentItem>>> getComments(int taskId);

  Future<Either<Failure, int>> addComment({
    required int taskId,
    required int authorId,
    required String body,
  });

  /// Удалить комментарий может только его автор.
  Future<Either<Failure, Unit>> deleteComment(
    int commentId, {
    required int requesterId,
  });
}
