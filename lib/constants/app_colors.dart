import 'package:flutter/material.dart';

import '../src/domain/entities/enums.dart';

Color priorityColor(TaskPriority p) => switch (p) {
  TaskPriority.low => Colors.green,
  TaskPriority.medium => Colors.blue,
  TaskPriority.high => Colors.orange,
  TaskPriority.critical => Colors.red,
};

Color statusColor(TaskStatus s) => switch (s) {
  TaskStatus.todo => Colors.grey,
  TaskStatus.inProgress => Colors.indigo,
  TaskStatus.done => Colors.green,
  TaskStatus.cancelled => Colors.brown,
};

Color projectStatusColor(ProjectStatus s) => switch (s) {
  ProjectStatus.active => Colors.green,
  ProjectStatus.completed => Colors.blue,
  ProjectStatus.archived => Colors.grey,
};
