import 'package:flutter/material.dart';

import '../../../core/error/failures.dart';
import '../../../core/utils/either.dart';
import '../../domain/entities/user.dart';
import 'run_action.dart';

typedef UserSaveCallback =
    Future<Either<Failure, Unit>> Function(String name, String email);

/// Диалог создания / редактирования пользователя.
Future<void> showUserDialog(
  BuildContext context, {
  User? user,
  required UserSaveCallback onSave,
}) async {
  final name = TextEditingController(text: user?.name ?? '');
  final email = TextEditingController(text: user?.email ?? '');
  await showDialog<void>(
    context: context,
    builder: (dc) => AlertDialog(
      title: Text(user == null ? 'Новый пользователь' : 'Редактирование'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('userName'),
            controller: name,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          TextField(
            key: const Key('userEmail'),
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dc),
          child: const Text('Отмена'),
        ),
        FilledButton(
          key: const Key('saveUser'),
          onPressed: () async {
            final ok = await runAction(dc, onSave(name.text, email.text));
            if (ok != null && dc.mounted) Navigator.pop(dc);
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}
