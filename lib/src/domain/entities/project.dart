import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'user.dart';

class Project extends Equatable {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.status,
    this.finishedAt,
  });

  final int id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final ProjectStatus status;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    createdAt,
    finishedAt,
    status,
  ];
}

/// Участник проекта вместе с данными пользователя.
class ProjectMember extends Equatable {
  const ProjectMember({
    required this.id,
    required this.projectId,
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  final int id;
  final int projectId;
  final User user;
  final MemberRole role;
  final DateTime joinedAt;

  @override
  List<Object?> get props => [id, projectId, user, role, joinedAt];
}
