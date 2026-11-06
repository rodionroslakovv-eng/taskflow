enum ProjectStatus {
  active('Активный'),
  completed('Завершённый'),
  archived('Архивный');

  const ProjectStatus(this.label);
  final String label;
}

enum MemberRole {
  owner('Owner'),
  admin('Admin'),
  member('Member');

  const MemberRole(this.label);
  final String label;
}

enum TaskStatus {
  todo('К выполнению'),
  inProgress('В работе'),
  done('Завершена'),
  cancelled('Отменена');

  const TaskStatus(this.label);
  final String label;

  /// Задача ещё не закрыта (учитывается в лимитах и при удалении пользователя).
  bool get isUnfinished => this == todo || this == inProgress;
}

/// Порядок значений важен: индекс хранится в БД (low=0 ... critical=3).
enum TaskPriority {
  low('Низкий'),
  medium('Средний'),
  high('Высокий'),
  critical('Критический');

  const TaskPriority(this.label);
  final String label;
}

enum HistoryKind {
  created('Создание'),
  status('Смена статуса'),
  assignee('Смена исполнителя'),
  undo('Отмена изменения');

  const HistoryKind(this.label);
  final String label;
}

enum TaskSort { createdAt, deadline }
