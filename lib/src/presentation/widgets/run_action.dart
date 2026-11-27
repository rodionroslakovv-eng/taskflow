import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../core/error/failure_message.dart';
import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';

/// Выполняет действие (UseCase через Cubit) и централизованно показывает
/// ошибку в SnackBar. Возвращает результат при успехе, иначе `null`.
Future<T?> runAction<T>(
  BuildContext context,
  Future<Either<Failure, T>> action,
) async {
  final result = await action;
  return result.fold<T?>((failure) {
    if (context.mounted) showSnack(context, failureMessage(failure));
    return null;
  }, (value) => value);
}
