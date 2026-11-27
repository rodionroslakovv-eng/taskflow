import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import '../utils/either.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Единственное место, где исключения превращаются в [Failure].
Failure mapExceptionToFailure(Object error, [StackTrace? stackTrace]) {
  if (error is ValidationException) {
    return ValidationFailure(error.message ?? 'Некорректные данные');
  }
  if (error is UnauthorizedException) return const UnauthorizedFailure();
  if (error is ServerException) return const ServerFailure();
  if (error is NetworkException ||
      error is SocketException ||
      error is TimeoutException) {
    return const NetworkFailure();
  }
  logError(error, stackTrace);
  return const UnknownFailure();
}

/// Технические детали попадают только в лог, но не в UI.
void logError(Object error, [StackTrace? stackTrace]) {
  developer.log(
    'Unhandled error',
    name: 'taskflow',
    error: error,
    stackTrace: stackTrace,
  );
}

/// Выполняет [body] и возвращает `Right(результат)` либо `Left(Failure)`.
Future<Either<Failure, T>> guardCall<T>(Future<T> Function() body) async {
  try {
    return Right<Failure, T>(await body());
  } catch (e, st) {
    return Left<Failure, T>(mapExceptionToFailure(e, st));
  }
}

/// Оборачивает поток данных: значения → `Right`, ошибка → `Left(Failure)`.
Stream<Either<Failure, T>> guardStream<T>(Stream<T> source) async* {
  try {
    await for (final value in source) {
      yield Right<Failure, T>(value);
    }
  } catch (e, st) {
    yield Left<Failure, T>(mapExceptionToFailure(e, st));
  }
}
