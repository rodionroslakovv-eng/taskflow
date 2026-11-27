import 'package:equatable/equatable.dart';

import 'user.dart';

class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.body,
    required this.authorId,
    required this.taskId,
    required this.createdAt,
  });

  final int id;
  final String body;
  final int authorId;
  final int taskId;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, body, authorId, taskId, createdAt];
}

class CommentItem extends Equatable {
  const CommentItem({required this.comment, required this.author});

  final Comment comment;
  final User author;

  @override
  List<Object?> get props => [comment, author];
}
