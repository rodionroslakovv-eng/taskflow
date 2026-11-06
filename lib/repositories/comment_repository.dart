import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../models/models.dart';

class CommentRepository {
  CommentRepository(this._db);
  final AppDatabase _db;

  Stream<List<CommentItem>> watchComments(int taskId) => _query(taskId).watch();

  Future<List<CommentItem>> getComments(int taskId) => _query(taskId).get();

  Selectable<CommentItem> _query(int taskId) {
    final c = _db.comments;
    final u = _db.users;
    final q = _db.select(c).join([innerJoin(u, u.id.equalsExp(c.authorId))])
      ..where(c.taskId.equals(taskId))
      ..orderBy([OrderingTerm.asc(c.createdAt), OrderingTerm.asc(c.id)]);
    return q.map(
      (r) => CommentItem(comment: r.readTable(c), author: r.readTable(u)),
    );
  }

  /// Комментарий к несуществующей задаче (или автором-несуществующим) запрещён.
  Future<int> addComment({
    required int taskId,
    required int authorId,
    required String body,
  }) async {
    final text = body.trim();
    if (text.isEmpty)
      throw TaskFlowException('Комментарий не может быть пустым');
    return _db.transaction(() async {
      final task = await (_db.select(
        _db.tasks,
      )..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (task == null) {
        throw TaskFlowException('Нельзя комментировать несуществующую задачу');
      }
      final author = await (_db.select(
        _db.users,
      )..where((u) => u.id.equals(authorId))).getSingleOrNull();
      if (author == null)
        throw TaskFlowException('Автор комментария не найден');
      return _db
          .into(_db.comments)
          .insert(
            CommentsCompanion.insert(
              body: text,
              authorId: authorId,
              taskId: taskId,
              createdAt: Value(DateTime.now()),
            ),
          );
    });
  }

  /// Удалить комментарий может только его автор.
  Future<void> deleteComment(int commentId, {required int requesterId}) async {
    await _db.transaction(() async {
      final c = await (_db.select(
        _db.comments,
      )..where((x) => x.id.equals(commentId))).getSingleOrNull();
      if (c == null) throw TaskFlowException('Комментарий не найден');
      if (c.authorId != requesterId) {
        throw TaskFlowException('Удалять комментарий может только его автор');
      }
      await (_db.delete(
        _db.comments,
      )..where((x) => x.id.equals(commentId))).go();
    });
  }
}
