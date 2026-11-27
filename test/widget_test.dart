import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/core/di/injection_container.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';
import 'package:taskflow/src/domain/usecases/task_usecases.dart';
import 'package:taskflow/src/domain/usecases/user_usecases.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await resetDependencies();
    await configureDependencies(
      executor: NativeDatabase.memory(),
      preferences: await SharedPreferences.getInstance(),
    );
  });

  tearDown(resetDependencies);

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(const TaskFlowApp());
    await tester.pumpAndSettle();
  }

  /// Даёт реальным асинхронным запросам к БД завершиться и перерисовывает кадр.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(resetDependencies);
  }

  testWidgets('главный экран: заголовок, навигация и пустые состояния', (
    tester,
  ) async {
    await openApp(tester);
    await settle(tester);

    expect(find.text('Проекты'), findsWidgets);
    expect(find.text('Задачи'), findsOneWidget);
    expect(find.text('Люди'), findsOneWidget);
    expect(find.text('Статистика'), findsWidgets);
    expect(find.byKey(const Key('addProjectFab')), findsOneWidget);
    expect(find.textContaining('Проектов пока нет'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('добавление пользователя через диалог и появление в списке', (
    tester,
  ) async {
    await openApp(tester);

    await tester.tap(find.text('Люди'));
    await settle(tester);
    expect(find.textContaining('Пользователей пока нет'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addUserFab')));
    await tester.pumpAndSettle();
    expect(find.text('Новый пользователь'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('userName')), 'Анна');
    await tester.enterText(find.byKey(const Key('userEmail')), 'anna@mail.com');
    await tester.tap(find.byKey(const Key('saveUser')));
    await settle(tester);

    expect(find.text('Новый пользователь'), findsNothing);
    expect(find.text('Анна'), findsOneWidget);
    expect(find.textContaining('anna@mail.com'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('повторный email показывает ошибку и не закрывает диалог', (
    tester,
  ) async {
    await tester.runAsync(
      () => getIt<CreateUserUseCase>()(name: 'Анна', email: 'anna@mail.com'),
    );
    await openApp(tester);

    await tester.tap(find.text('Люди'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('addUserFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('userName')), 'Двойник');
    await tester.enterText(find.byKey(const Key('userEmail')), 'ANNA@mail.com');
    await tester.tap(find.byKey(const Key('saveUser')));
    await settle(tester);

    expect(
      find.text('Пользователь с таким email уже существует'),
      findsOneWidget,
    );
    expect(find.text('Новый пользователь'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('экран статистики обновляется после изменения данных (watch)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final createProject = getIt<CreateProjectUseCase>();
    final createTask = getIt<CreateTaskUseCase>();
    final changeStatus = getIt<ChangeTaskStatusUseCase>();
    final projectId = (await tester.runAsync(
      () => createProject(name: 'Alpha'),
    ))!.value;
    await openApp(tester);

    await tester.tap(find.text('Статистика').last);
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('stat_Всего задач'))).data,
      '0',
    );

    await tester.runAsync(() => createTask(title: 'T1', projectId: projectId));
    await settle(tester);
    final t2 = (await tester.runAsync(
      () => createTask(title: 'T2', projectId: projectId),
    ))!.value;
    await settle(tester);
    await tester.runAsync(() => changeStatus(t2, TaskStatus.done));
    await settle(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('stat_Всего задач'))).data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('stat_Завершено'))).data,
      '1',
    );
    expect(find.textContaining('50%'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('переход между экранами: проект → форма новой задачи → назад', (
    tester,
  ) async {
    await tester.runAsync(() => getIt<CreateProjectUseCase>()(name: 'Alpha'));
    await openApp(tester);
    await settle(tester);

    await tester.tap(find.text('Alpha'));
    await settle(tester);
    expect(find.text('Участники'), findsOneWidget);
    expect(find.byKey(const Key('taskSearch')), findsOneWidget);

    await tester.tap(find.byKey(const Key('addTaskFab')));
    await settle(tester);
    expect(find.text('Новая задача'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    expect(find.text('Новая задача'), findsNothing);

    await closeApp(tester);
  });

  testWidgets('новая функция: задача добавляется в «Избранное» и видна там', (
    tester,
  ) async {
    final projectId = (await tester.runAsync(
      () => getIt<CreateProjectUseCase>()(name: 'Alpha'),
    ))!.value;
    final taskId = (await tester.runAsync(
      () => getIt<CreateTaskUseCase>()(title: 'Важная', projectId: projectId),
    ))!.value;
    await openApp(tester);

    await tester.tap(find.text('Alpha'));
    await settle(tester);
    await tester.tap(find.byKey(Key('favorite_$taskId')));
    await settle(tester);

    // Назад на главный экран и в меню «Избранное».
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Избранное'));
    await settle(tester);

    expect(find.text('Важная'), findsOneWidget);

    await closeApp(tester);
  });
}
