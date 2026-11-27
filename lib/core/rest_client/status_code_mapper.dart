import '../error/exceptions.dart';

/// Правило преобразования HTTP-статуса в исключение Data Layer.
/// Приложение сейчас работает с локальной БД, но при появлении REST API
/// Remote DataSource будет использовать именно это место, поэтому
/// таблица «ситуация → обработка» из задания реализована заранее:
/// 400 → Validation, 401 → Unauthorized, 5xx → Server.
AppException exceptionFromStatusCode(int statusCode, {String? message}) {
  if (statusCode == 400 || statusCode == 422) {
    return ValidationException(message ?? 'Некорректный запрос');
  }
  if (statusCode == 401 || statusCode == 403) {
    return UnauthorizedException(message);
  }
  return ServerException(statusCode: statusCode, message: message);
}
