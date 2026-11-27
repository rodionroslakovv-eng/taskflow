import '../../../core/error/error_handler.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../datasources/local/comment_local_data_source.dart';
import '../mapper/mappers.dart';

class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl(this._local);
  final CommentLocalDataSource _local;

  @override
  Stream<Either<Failure, List<CommentItem>>> watchComments(int taskId) =>
      guardStream(
        _local
            .watchComments(taskId)
            .map((rows) => rows.map((r) => r.toEntity()).toList()),
      );

  @override
  Future<Either<Failure, List<CommentItem>>> getComments(int taskId) =>
      guardCall(() async {
        final rows = await _local.getComments(taskId);
        return rows.map((r) => r.toEntity()).toList();
      });

  @override
  Future<Either<Failure, int>> addComment({
    required int taskId,
    required int authorId,
    required String body,
  }) => guardCall(
    () => _local.addComment(taskId: taskId, authorId: authorId, body: body),
  );

  @override
  Future<Either<Failure, Unit>> deleteComment(
    int commentId, {
    required int requesterId,
  }) => guardCall(() async {
    await _local.deleteComment(commentId, requesterId: requesterId);
    return unit;
  });
}
