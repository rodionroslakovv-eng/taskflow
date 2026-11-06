import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'database/app_database.dart';
import 'database/connection.dart';
import 'presentation/home_screen.dart';
import 'repositories/repositories.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repos = Repositories(AppDatabase(openConnection()));
  runApp(TaskFlowApp(repos: repos));
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key, required this.repos});

  final Repositories repos;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Repositories>.value(value: repos),
        ChangeNotifierProvider<AppState>(create: (_) => AppState(repos)),
      ],
      child: MaterialApp(
        title: 'TaskFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
