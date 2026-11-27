import 'package:equatable/equatable.dart';

class Attachment extends Equatable {
  const Attachment({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.taskId,
    required this.addedAt,
  });

  final int id;
  final String fileName;

  /// В БД хранится только путь к файлу, не содержимое.
  final String filePath;
  final int taskId;
  final DateTime addedAt;

  @override
  List<Object?> get props => [id, fileName, filePath, taskId, addedAt];
}
