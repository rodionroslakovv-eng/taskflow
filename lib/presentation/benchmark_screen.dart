import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../repositories/performance_service.dart';

/// Производительность: отдельная тестовая БД (1000 / 100 / 10 000),
/// сравнение запросов с индексами и без. Основная БД не затрагивается.
class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  String _status =
      'Нажмите «Запустить», чтобы создать тестовую БД и измерить запросы.';
  bool _busy = false;
  List<BenchmarkResult> _results = [];

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _results = [];
      _status = 'Создание тестовой БД…';
    });
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'taskflow_perf.sqlite'));
    if (await file.exists()) await file.delete();
    final db = AppDatabase(NativeDatabase(file));
    try {
      final svc = PerformanceService(db);
      final sw = Stopwatch()..start();
      await svc.seed();
      if (!mounted) return;
      setState(
        () => _status =
            'Данные созданы за ${sw.elapsedMilliseconds} мс (1000 пользователей, 100 проектов, 10 000 задач). Измерение…',
      );
      final res = await svc.benchmark();
      if (!mounted) return;
      setState(() {
        _results = res;
        _status = 'Готово. Время — среднее за запрос, мс.';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Ошибка: $e');
    } finally {
      await db.close();
      if (await file.exists()) await file.delete();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Производительность')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_status),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _run,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed),
            label: const Text('Запустить'),
          ),
          const SizedBox(height: 16),
          if (_results.isNotEmpty)
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
                  for (final r in _results)
                    DataRow(
                      cells: [
                        DataCell(Text(r.name)),
                        DataCell(Text(r.withIndexMs.toStringAsFixed(2))),
                        DataCell(Text(r.withoutIndexMs.toStringAsFixed(2))),
                        DataCell(Text('×${r.speedup.toStringAsFixed(1)}')),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
