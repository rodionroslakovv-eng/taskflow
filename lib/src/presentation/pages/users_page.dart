import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../components/components.dart';
import '../../../core/di/injection_container.dart';
import '../../domain/entities/user.dart';
import '../bloc/common/view_state.dart';
import '../bloc/users/users_cubits.dart';
import '../widgets/run_action.dart';
import '../widgets/task_list_view.dart';
import '../widgets/user_dialog.dart';
import '../widgets/view_state_builder.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        key: const Key('addUserFab'),
        onPressed: () {
          final cubit = context.read<UsersCubit>();
          showUserDialog(
            context,
            onSave: (name, email) => cubit.create(name: name, email: email),
          );
        },
        child: const Icon(Icons.person_add),
      ),
      body: ViewStateBuilder<UsersCubit, List<User>>(
        emptyText: 'Пользователей пока нет.\nНажмите «+», чтобы добавить.',
        builder: (context, users) => ListView.separated(
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
                  builder: (_) => UserDetailPage(userId: u.id),
                ),
              ),
              trailing: IconButton(
                tooltip: 'Удалить',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final cubit = context.read<UsersCubit>();
                  if (await confirm(
                        context,
                        'Удалить пользователя «${u.name}»?',
                      ) &&
                      context.mounted) {
                    await runAction(context, cubit.delete(u.id));
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class UserDetailPage extends StatelessWidget {
  const UserDetailPage({super.key, required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserDetailCubit>(
      create: (_) => getIt<UserDetailCubit>(param1: userId)..load(),
      child: BlocBuilder<UserDetailCubit, ViewState<User?>>(
        builder: (context, state) {
          final u = switch (state) {
            ViewSuccess<User?>(:final data) => data,
            _ => null,
          };
          return Scaffold(
            appBar: AppBar(
              title: Text(u?.name ?? 'Пользователь'),
              actions: [
                if (u != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      final cubit = context.read<UserDetailCubit>();
                      showUserDialog(
                        context,
                        user: u,
                        onSave: (name, email) =>
                            cubit.update(name: name, email: email),
                      );
                    },
                  ),
              ],
            ),
            body: switch (state) {
              ViewSuccess<User?>(:final data) when data != null => Column(
                children: [
                  ListTile(
                    title: Text(data.email),
                    subtitle: Text(
                      'Зарегистрирован: ${fmtDate(data.registeredAt)}',
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
              ViewInitial<User?>() || ViewLoading<User?>() => const LoadingView(),
              ViewError<User?>() => ErrorView(
                message: 'Не удалось загрузить пользователя',
                onRetry: context.read<UserDetailCubit>().retry,
              ),
              _ => const EmptyState('Пользователь удалён'),
            },
          );
        },
      ),
    );
  }
}
