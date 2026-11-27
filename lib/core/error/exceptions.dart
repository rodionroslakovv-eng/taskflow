/// Исключения Data Layer. Выбрасываются источниками данных и никогда
/// не доходят до UI: репозитории превращают их в `Failure`.
abstract class AppException implements Exception {
  const AppException([this.message]);
  final String? message;

  @override
  String toString() => '$runtimeType${message == null ? '' : ': $message'}';
}

class NetworkException extends AppException {
  const NetworkException([super.message]);
}

class ServerException extends AppException {
  const ServerException({this.statusCode, String? message}) : super(message);
  final int? statusCode;
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message]);
}

/// Неверный запрос / нарушение бизнес-правила. [message] безопасно показывать
/// пользователю.
class ValidationException extends AppException {
  const ValidationException(String message) : super(message);
}
