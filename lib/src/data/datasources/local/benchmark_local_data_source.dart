import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../constants/app_constants.dart';
import '../../../../models/app_database.dart';
import '../../../../models/stats_models.dart';
import 'performance_service.dart';

abstract class BenchmarkLocalDataSource {
  Future<BenchmarkReportModel> run();
}

/// Отдельная тестовая БД (1000 / 100 / 10 000), основная БД не затрагивается.
class BenchmarkLocalDataSourceImpl implements BenchmarkLocalDataSource {
  BenchmarkLocalDataSourceImpl({
    Future<Directory> Function()? documentsDirectory,
  }) : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  @override
  Future<BenchmarkReportModel> run() async {
    final dir = await _documentsDirectory();
    final file = File(p.join(dir.path, AppConstants.benchmarkDatabaseFileName));
    if (await file.exists()) await file.delete();
    final db = AppDatabase(NativeDatabase(file));
    try {
      final service = PerformanceService(db);
      final sw = Stopwatch()..start();
      await service.seed();
      final seedMs = sw.elapsedMilliseconds;
      final results = await service.benchmark();
      return BenchmarkReportModel(seedMs: seedMs, results: results);
    } finally {
      await db.close();
      if (await file.exists()) await file.delete();
    }
  }
}
