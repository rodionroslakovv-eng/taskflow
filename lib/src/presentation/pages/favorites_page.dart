import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../domain/entities/task.dart';
import '../bloc/favorites/favorites_cubits.dart';
import '../widgets/task_tile.dart';
import '../widgets/view_state_builder.dart';

/// Избранные задачи (список id хранится локально на устройстве).
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FavoriteTasksCubit>(
      create: (_) => getIt<FavoriteTasksCubit>()..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Избранное')),
        body: ViewStateBuilder<FavoriteTasksCubit, List<TaskItem>>(
          emptyText:
              'В избранном пока ничего нет.\nНажмите на звёздочку у задачи.',
          builder: (context, items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => TaskTile(item: items[i]),
          ),
        ),
      ),
    );
  }
}
