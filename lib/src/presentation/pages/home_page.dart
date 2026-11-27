import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../constants/app_constants.dart';
import '../../domain/entities/user.dart';
import '../bloc/common/view_state.dart';
import '../bloc/users/users_cubits.dart';
import '../widgets/task_list_view.dart';
import 'benchmark_page.dart';
import 'dashboard_page.dart';
import 'favorites_page.dart';
import 'projects_page.dart';
import 'task_form_page.dart';
import 'trash_page.dart';
import 'users_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  static const _titles = ['Проекты', 'Задачи', 'Пользователи', 'Статистика'];

  void _openMenuItem(String value) {
    final page = switch (value) {
      'trash' => const TrashPage(),
      'favorites' => const FavoritesPage(),
      _ => const BenchmarkPage(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          const _CurrentUserPicker(),
          PopupMenuButton<String>(
            key: const Key('homeMenu'),
            onSelected: _openMenuItem,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'favorites', child: Text('Избранное')),
              PopupMenuItem(value: 'trash', child: Text('Корзина')),
              PopupMenuItem(value: 'bench', child: Text('Производительность')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ProjectsPage(),
          _AllTasksTab(),
          UsersPage(),
          DashboardPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: 'Проекты',
          ),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Задачи'),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Люди',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Статистика',
          ),
        ],
      ),
    );
  }
}

class _AllTasksTab extends StatelessWidget {
  const _AllTasksTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TaskFormPage()),
        ),
        child: const Icon(Icons.add_task),
      ),
      body: const TaskListView(),
    );
  }
}

/// Выбор «текущего пользователя»: от его имени пишутся история и комментарии.
class _CurrentUserPicker extends StatelessWidget {
  const _CurrentUserPicker();

  @override
  Widget build(BuildContext context) {
    final currentId = context.watch<CurrentUserCubit>().state.userId;
    return BlocBuilder<UsersCubit, ViewState<List<User>>>(
      builder: (context, state) {
        final users = switch (state) {
          ViewSuccess<List<User>>(:final data) => data,
          _ => const <User>[],
        };
        if (users.isEmpty) return const SizedBox.shrink();
        return PopupMenuButton<int>(
          tooltip: 'Текущий пользователь',
          onSelected: context.read<CurrentUserCubit>().select,
          icon: const Icon(Icons.account_circle),
          itemBuilder: (_) => [
            for (final u in users.take(AppConstants.maxUsersInMenu))
              CheckedPopupMenuItem(
                value: u.id,
                checked: u.id == currentId,
                child: Text(u.name),
              ),
          ],
        );
      },
    );
  }
}
