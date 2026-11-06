import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/repositories.dart';

/// Глобальное состояние: «текущий пользователь» (от его имени пишутся
/// история изменений и комментарии).
class AppState extends ChangeNotifier {
  AppState(this._repos) {
    _sub = _repos.users.watchUsers().listen((list) {
      final ids = list.map((u) => u.id);
      if (_currentUserId == null || !ids.contains(_currentUserId)) {
        _currentUserId = list.isEmpty ? null : list.first.id;
        notifyListeners();
      }
    });
  }

  final Repositories _repos;
  StreamSubscription? _sub;
  int? _currentUserId;

  int? get currentUserId => _currentUserId;

  void setCurrentUser(int? id) {
    _currentUserId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
