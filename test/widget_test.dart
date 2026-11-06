import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/main.dart';
import 'package:taskflow/models/enums.dart';
import 'package:taskflow/repositories/repositories.dart';

void main() {
  late Repositories repos;

  setUp(() {
    repos = Repositories(AppDatabase(NativeDatabase.memory()));
  });

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(TaskFlowApp(repos: repos));
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
    await tester.runAsync(repos.db.close);
  }

  testWidgets('главный экран: заголовок, навигация и пустые состояния', (
    tester,
  ) async {
    await openApp(tester);

    expect(find.text('Проекты'), findsWidgets); // заголовок + пункт навигации
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
    await tester.pumpAndSettle();
    expect(find.textContaining('Пользователей пока нет'), findsOneWidget);

    await tester.tap(find.byKey(const Key('addUserFab')));
    await tester.pumpAndSettle();
    expect(find.text('Новый пользователь'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('userName')), 'Анна');
    await tester.enterText(find.byKey(const Key('userEmail')), 'anna@mail.com');
    await tester.tap(find.byKey(const Key('saveUser')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Новый пользователь'), findsNothing); // диалог закрыт
    expect(find.text('Анна'), findsOneWidget);
    expect(find.textContaining('anna@mail.com'), findsOneWidget);

    await closeApp(tester);
  });

  testWidgets('повторный email показывает ошибку и не закрывает диалог', (
    tester,
  ) async {
    await tester.runAsync(
      () => repos.users.createUser(name: 'Анна', email: 'anna@mail.com'),
    );
    await openApp(tester);

    await tester.tap(find.text('Люди'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addUserFab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('userName')), 'Двойник');
    await tester.enterText(find.byKey(const Key('userEmail')), 'ANNA@mail.com');
    await tester.tap(find.byKey(const Key('saveUser')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Пользователь с таким email уже существует'),
      findsOneWidget,
    );
    expect(find.text('Новый пользователь'), findsOneWidget);
    expect(await tester.runAsync(() => repos.users.getUsers()), hasLength(1));

    await closeApp(tester);
  });

  testWidgets('экран статистики обновляется после изменения данных (watch)', (
    tester,
  ) async {
    // Высокий экран, чтобы весь Dashboard (ленивый ListView) был построен.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late int projectId;
    await tester.runAsync(() async {
      projectId = await repos.projects.createProject(name: 'Alpha');
    });
    await openApp(tester);

    await tester.tap(find.text('Статистика').last);
    await settle(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('stat_Всего задач'))).data,
      '0',
    );

    // Каждую операцию с БД выполняем отдельно и сразу перерисовываем кадр:
    // потоки Drift живут в «фейковом» времени теста и без pump не обработают запрос.
    await tester.runAsync(
      () => repos.tasks.createTask(title: 'T1', projectId: projectId),
    );
    await settle(tester);
    final t2 = (await tester.runAsync(
      () => repos.tasks.createTask(title: 'T2', projectId: projectId),
    ))!;
    await settle(tester);
    await tester.runAsync(() => repos.tasks.changeStatus(t2, TaskStatus.done));
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
    await tester.runAsync(() => repos.projects.createProject(name: 'Alpha'));
    await openApp(tester);

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
}
