import 'failures.dart';

/// Человекочитаемый текст ошибки. Необработанный текст исключений
/// пользователю не показывается никогда.
String failureMessage(Failure failure) => switch (failure) {
  NetworkFailure() => 'Нет подключения к интернету',
  ServerFailure() => 'Ошибка сервера. Попробуйте позже',
  UnauthorizedFailure() => 'Требуется авторизация',
  ValidationFailure(:final message) => message ?? 'Некорректные данные',
  _ => 'Произошла неизвестная ошибка',
};
