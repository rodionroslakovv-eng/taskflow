import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/error/error_handler.dart';
import 'package:taskflow/core/error/exceptions.dart';
import 'package:taskflow/core/error/failure_message.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/core/rest_client/status_code_mapper.dart';
import 'package:taskflow/core/utils/either.dart';

void main() {
  group('Either', () {
    test('fold и map', () {
      const Either<Failure, int> ok = Right(2);
      const Either<Failure, int> bad = Left(NetworkFailure());
      expect(ok.fold((_) => -1, (v) => v * 2), 4);
      expect(bad.fold((_) => -1, (v) => v * 2), -1);
      expect(ok.map((v) => v + 1), const Right<Failure, int>(3));
      expect(bad.map((v) => v + 1), bad);
      expect(ok.rightOrNull, 2);
      expect(bad.leftOrNull, const NetworkFailure());
    });
  });

  group('Таблица «ситуация → Failure»', () {
    test('нет сети -> NetworkFailure', () {
      expect(
        mapExceptionToFailure(const SocketException('x')),
        const NetworkFailure(),
      );
      expect(
        mapExceptionToFailure(TimeoutException('x')),
        const NetworkFailure(),
      );
      expect(
        mapExceptionToFailure(const NetworkException()),
        const NetworkFailure(),
      );
    });

    test('400 -> ValidationFailure с текстом', () {
      expect(
        mapExceptionToFailure(exceptionFromStatusCode(400, message: 'bad')),
        const ValidationFailure('bad'),
      );
    });

    test('401 -> UnauthorizedFailure', () {
      expect(
        mapExceptionToFailure(exceptionFromStatusCode(401)),
        const UnauthorizedFailure(),
      );
    });

    test('500 -> ServerFailure', () {
      expect(
        mapExceptionToFailure(exceptionFromStatusCode(500)),
        const ServerFailure(),
      );
    });

    test('неизвестная ошибка -> UnknownFailure без технических деталей', () {
      final f = mapExceptionToFailure(StateError('SELECT * FROM secret'));
      expect(f, const UnknownFailure());
      expect(failureMessage(f), isNot(contains('SELECT')));
    });
  });

  group('guardCall / guardStream', () {
    test('guardCall: успех и ошибка', () async {
      expect(await guardCall(() async => 5), const Right<Failure, int>(5));
      final r = await guardCall<int>(
        () async => throw const ValidationException('нельзя'),
      );
      expect(r, const Left<Failure, int>(ValidationFailure('нельзя')));
    });

    test('guardStream: значения -> Right, исключение -> Left', () async {
      Stream<int> source() async* {
        yield 1;
        throw const ServerException(statusCode: 500);
      }

      final out = await guardStream(source()).toList();
      expect(out, [
        const Right<Failure, int>(1),
        const Left<Failure, int>(ServerFailure()),
      ]);
    });
  });

  test('failureMessage: текст для каждого вида Failure', () {
    expect(failureMessage(const NetworkFailure()), 'Нет подключения к интернету');
    expect(failureMessage(const ValidationFailure('x')), 'x');
    expect(failureMessage(const UnauthorizedFailure()), isNotEmpty);
    expect(failureMessage(const ServerFailure()), isNotEmpty);
  });
}
