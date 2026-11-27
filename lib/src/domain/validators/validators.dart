import '../../../core/error/failures.dart';

/// Чистые правила валидации ввода (без доступа к данным).
/// Возвращают `null`, если значение корректно, иначе [ValidationFailure].
abstract final class Validators {
  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static Failure? userName(String value) {
    final v = value.trim();
    if (v.isEmpty) return const ValidationFailure('Имя не может быть пустым');
    if (v.length > 100) return const ValidationFailure('Имя слишком длинное');
    return null;
  }

  static Failure? email(String value) {
    if (!_emailRe.hasMatch(value.trim().toLowerCase())) {
      return const ValidationFailure('Некорректный email');
    }
    return null;
  }

  static Failure? projectName(String value) {
    final v = value.trim();
    if (v.isEmpty) {
      return const ValidationFailure('Название проекта не может быть пустым');
    }
    if (v.length > 150) {
      return const ValidationFailure('Название проекта слишком длинное');
    }
    return null;
  }

  static Failure? taskTitle(String value) {
    final v = value.trim();
    if (v.isEmpty) {
      return const ValidationFailure('Название задачи не может быть пустым');
    }
    if (v.length > 200) {
      return const ValidationFailure('Название задачи слишком длинное');
    }
    return null;
  }

  static Failure? commentBody(String value) {
    final v = value.trim();
    if (v.isEmpty) {
      return const ValidationFailure('Комментарий не может быть пустым');
    }
    if (v.length > 2000) {
      return const ValidationFailure('Комментарий слишком длинный');
    }
    return null;
  }

  static Failure? fileName(String value) {
    if (value.trim().isEmpty) return const ValidationFailure('Некорректный файл');
    return null;
  }
}
