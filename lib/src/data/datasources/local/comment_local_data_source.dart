import 'package:drift/drift.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../models/app_database.dart';
import '../../../../models/relation_models.dart';

abstract class CommentLocalDataSource {
  Stream<List<CommentModel>> watchComments(int taskId);
  Future<List<CommentModel>> getComments(int taskId);
  Future<int> addComment({
    required int taskId,
    required int authorId,
    required String body,
  });
  Future<void> deleteComment(int commentId, {required int requesterId});
}

class CommentLocalDataSourceImpl implements CommentLocalDataSource {
  CommentLocalDataSourceImpl(this._db);
  final AppDatabase _db;

  Selectable<CommentModel> _query(int taskId) {
    final c = _db.comments;
    final u = _db.users;
    final q = _db.select(c).join([innerJoin(u, u.id.equalsExp(c.authorId))])
      ..where(c.taskId.equals(taskId))
      ..orderBy([OrderingTerm.asc(c.createdAt), OrderingTerm.asc(c.id)]);
    return q.map(
      (r) => CommentModel(comment: r.readTable(c), author: r.readTable(u)),
    );
  }

  @override
  Stream<List<CommentModel>> watchComments(int taskId) => _query(taskId).watch();

  @override
  Future<List<CommentModel>> getComments(int taskId) => _query(taskId).get();

  /// Комментарий к несуществующей задаче (или автором-несуществующим) запрещён.
  @override
  Future<int> addComment({
    required int taskId,
    required int authorId,
    required String body,
  }) {
    return _db.transaction(() async {
      final task = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (task == null) {
        throw const ValidationException(
          'Нельзя комментировать несуществующую задачу',
        );
      }
      final author = await (_db.select(
        _db.users,
      )..where((u) => u.id.equals(authorId))).getSingleOrNull();
      if (author == null) {
        throw const ValidationException('Автор комментария не найден');
      }
      return _db
          .into(_db.comments)
          .insert(
            CommentsCompanion.insert(
              body: body,
              authorId: authorId,
              taskId: taskId,
              createdAt: Value(DateTime.now()),
            ),
          );
    });
  }

  /// Удалить комментарий может только его автор.
  @override
  Future<void> deleteComment(int commentId, {required int requesterId}) {
    return _db.transaction(() async {
      final c = await (_db.select(
        _db.comments,
      )..where((x) => x.id.equals(commentId))).getSingleOrNull();
      if (c == null) throw const ValidationException('Комментарий не найден');
      if (c.authorId != requesterId) {
        throw const ValidationException(
          'Удалять комментарий может только его автор',
        );
      }
      await (_db.delete(
        _db.comments,
      )..where((x) => x.id.equals(commentId))).go();
    });
  }
}
