import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/models.dart';
import '../repositories/task_repository.dart';

/// Состояние списка задач: фильтры, поиск, сортировка, пагинация.
/// Данные приходят потоком Drift watch() и обновляются автоматически.
class TaskListController extends ChangeNotifier {
  TaskListController(
    this._repo, {
    int? projectId,
    int? assigneeId,
    bool onlyDeleted = false,
    this.pageSize = 20,
  }) : _filter = TaskFilter(
         projectId: projectId,
         assigneeId: assigneeId,
         onlyDeleted: onlyDeleted,
       ) {
    _rebuild();
  }

  final TaskRepository _repo;
  final int pageSize;
  TaskFilter _filter;
  int _pages = 1;
  late Stream<List<TaskItem>> _stream;

  TaskFilter get filter => _filter;
  int get limit => pageSize * _pages;
  Stream<List<TaskItem>> get stream => _stream;

  void _rebuild() {
    _stream = _repo.watchTasks(_filter.copyWith(limit: limit, offset: 0));
    notifyListeners();
  }

  void _update(TaskFilter f) {
    _filter = f;
    _pages = 1;
    _rebuild();
  }

  void setQuery(String q) => _update(_filter.copyWith(query: q));
  void setStatus(TaskStatus? s) => _update(_filter.copyWith(status: s));
  void setPriority(TaskPriority? p) => _update(_filter.copyWith(priority: p));
  void setAssignee(int? id) => _update(_filter.copyWith(assigneeId: id));
  void setSort(TaskSort s) => _update(_filter.copyWith(sort: s));
  void toggleDirection() =>
      _update(_filter.copyWith(ascending: !_filter.ascending));

  void loadMore() {
    _pages++;
    _rebuild();
  }
}
