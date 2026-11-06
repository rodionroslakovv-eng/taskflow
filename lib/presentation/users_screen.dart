import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../repositories/repositories.dart';
import 'task_list_view.dart';
import 'widgets.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        key: const Key('addUserFab'),
        onPressed: () => showUserDialog(context),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<List<UserRow>>(
        stream: repos.users.watchUsers(),
        builder: (context, snap) {
          final users = snap.data ?? [];
          if (users.isEmpty) {
            return const EmptyState(
              'Пользователей пока нет.\nНажмите «+», чтобы добавить.',
            );
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(u.name.characters.first.toUpperCase()),
                ),
                title: Text(u.name),
                subtitle: Text(
                  '${u.email}\nРегистрация: ${fmtDate(u.registeredAt)}',
                ),
                isThreeLine: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserDetailScreen(userId: u.id),
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Удалить',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(
                          context,
                          'Удалить пользователя «${u.name}»?',
                        ) &&
                        context.mounted) {
                      await guard(context, () => repos.users.deleteUser(u.id));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> showUserDialog(BuildContext context, {UserRow? user}) async {
  final repos = context.read<Repositories>();
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
            final ok = await guard(dc, () async {
              if (user == null) {
                await repos.users.createUser(
                  name: name.text,
                  email: email.text,
                );
              } else {
                await repos.users.updateUser(
                  user.id,
                  name: name.text,
                  email: email.text,
                );
              }
              return true;
            });
            if (ok == true && dc.mounted) Navigator.pop(dc);
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

class UserDetailScreen extends StatelessWidget {
  const UserDetailScreen({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context) {
    final repos = context.read<Repositories>();
    return StreamBuilder<UserRow?>(
      stream: repos.users.watchUser(userId),
      builder: (context, snap) {
        final u = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(u?.name ?? 'Пользователь'),
            actions: [
              if (u != null)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => showUserDialog(context, user: u),
                ),
            ],
          ),
          body: u == null
              ? const EmptyState('Пользователь удалён')
              : Column(
                  children: [
                    ListTile(
                      title: Text(u.email),
                      subtitle: Text(
                        'Зарегистрирован: ${fmtDate(u.registeredAt)}',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Задачи пользователя',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: TaskListView(assigneeId: userId)),
                  ],
                ),
        );
      },
    );
  }
}
