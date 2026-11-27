import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/error/failure_message.dart';
import '../../domain/entities/benchmark.dart';
import '../bloc/benchmark/benchmark_cubit.dart';
import '../bloc/common/view_state.dart';

/// Производительность: отдельная тестовая БД (1000 / 100 / 10 000),
/// сравнение запросов с индексами и без. Основная БД не затрагивается.
class BenchmarkPage extends StatelessWidget {
  const BenchmarkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BenchmarkCubit>(
      create: (_) => getIt<BenchmarkCubit>(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Производительность')),
        body: BlocBuilder<BenchmarkCubit, ViewState<BenchmarkReport>>(
          builder: (context, state) {
            final busy = state is ViewLoading<BenchmarkReport>;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(switch (state) {
                  ViewInitial<BenchmarkReport>() =>
                    'Нажмите «Запустить», чтобы создать тестовую БД и измерить запросы.',
                  ViewLoading<BenchmarkReport>() =>
                    'Создание тестовой БД и измерение запросов…',
                  ViewSuccess<BenchmarkReport>(:final data) =>
                    'Готово. Данные созданы за ${data.seedMs} мс '
                        '(1000 пользователей, 100 проектов, 10 000 задач). '
                        'Время — среднее за запрос, мс.',
                  ViewError<BenchmarkReport>(:final failure) =>
                    failureMessage(failure),
                  ViewEmpty<BenchmarkReport>() => 'Нет данных',
                }),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy ? null : context.read<BenchmarkCubit>().run,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.speed),
                  label: const Text('Запустить'),
                ),
                const SizedBox(height: 16),
                if (state case ViewSuccess<BenchmarkReport>(:final data))
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Запрос')),
                        DataColumn(label: Text('С индексами'), numeric: true),
                        DataColumn(label: Text('Без индексов'), numeric: true),
                        DataColumn(label: Text('Ускорение'), numeric: true),
                      ],
                      rows: [
                        for (final r in data.results)
                          DataRow(
                            cells: [
                              DataCell(Text(r.name)),
                              DataCell(Text(r.withIndexMs.toStringAsFixed(2))),
                              DataCell(
                                Text(r.withoutIndexMs.toStringAsFixed(2)),
                              ),
                              DataCell(Text('×${r.speedup.toStringAsFixed(1)}')),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
