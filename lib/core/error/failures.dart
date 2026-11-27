import 'package:equatable/equatable.dart';

/// Иерархия ошибок, которую видят Domain и Presentation слои.
/// Исключения Data Layer ([AppException]) превращаются в Failure в одном месте —
/// см. `error_handler.dart`.
abstract class Failure extends Equatable {
  const Failure([this.message]);

  /// Безопасный для показа пользователю текст (если он есть).
  final String? message;

  @override
  List<Object?> get props => [message];
}

/// Нет интернета / сеть недоступна.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message]);
}

/// Ошибка сервера (HTTP 5xx).
class ServerFailure extends Failure {
  const ServerFailure([super.message]);
}

/// Ошибка авторизации (HTTP 401).
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message]);
}

/// Неверный запрос (HTTP 400) или нарушение бизнес-правила.
class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message);
}

/// Любая непредвиденная ошибка.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message]);
}
