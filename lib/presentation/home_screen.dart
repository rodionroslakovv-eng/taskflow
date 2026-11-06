import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../repositories/repositories.dart';
import '../state/app_state.dart';
import 'benchmark_screen.dart';
import 'dashboard_screen.dart';
import 'projects_screen.dart';
import 'task_form_screen.dart';
import 'task_list_view.dart';
import 'trash_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  static const _titles = ['Проекты', 'Задачи', 'Пользователи', 'Статистика'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          const _CurrentUserPicker(),
          PopupMenuButton<String>(
            onSelected: (v) {
              final page = v == 'trash'
                  ? const TrashScreen()
                  : const BenchmarkScreen();
              Navigator.push(context, MaterialPageRoute(builder: (_) => page));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'trash', child: Text('Корзина')),
              PopupMenuItem(value: 'bench', child: Text('Производительность')),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          ProjectsScreen(),
          _AllTasksTab(),
          UsersScreen(),
          DashboardScreen(),
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
          MaterialPageRoute(builder: (_) => const TaskFormScreen()),
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
    final repos = context.read<Repositories>();
    final state = context.watch<AppState>();
    return StreamBuilder<List<UserRow>>(
      stream: repos.users.watchUsers(),
      builder: (context, snap) {
        final users = snap.data ?? [];
        if (users.isEmpty) return const SizedBox.shrink();
        final current = users
            .where((u) => u.id == state.currentUserId)
            .firstOrNull;
        return PopupMenuButton<int>(
          tooltip: 'Текущий пользователь',
          onSelected: state.setCurrentUser,
          icon: const Icon(Icons.account_circle),
          itemBuilder: (_) => [
            for (final u in users.take(50))
              CheckedPopupMenuItem(
                value: u.id,
                checked: u.id == current?.id,
                child: Text(u.name),
              ),
          ],
        );
      },
    );
  }
}
