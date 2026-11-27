import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/error/error_handler.dart';
import 'src/presentation/bloc/favorites/favorites_cubits.dart';
import 'src/presentation/bloc/users/users_cubits.dart';
import 'src/presentation/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Централизованный лог необработанных ошибок: технические детали
  // попадают в лог, а не на экран пользователя.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    logError(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logError(error, stack);
    return true;
  };

  await configureDependencies();
  runApp(const TaskFlowApp());
}

/// Корень приложения. Глобальные Cubit'ы: список пользователей,
/// «текущий пользователь» и избранное. Зависимости берутся из GetIt.
class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UsersCubit>(create: (_) => getIt<UsersCubit>()..load()),
        BlocProvider<CurrentUserCubit>(create: (_) => getIt<CurrentUserCubit>()),
        BlocProvider<FavoritesCubit>(create: (_) => getIt<FavoritesCubit>()),
      ],
      child: MaterialApp(
        title: AppConstants.appTitle,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
          useMaterial3: true,
        ),
        home: const HomePage(),
      ),
    );
  }
}
