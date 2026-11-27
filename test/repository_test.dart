import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/constants/business_rules.dart';
import 'package:taskflow/core/error/failures.dart';
import 'package:taskflow/src/data/datasources/local/attachment_local_data_source.dart';
import 'package:taskflow/src/data/repositories/attachment_repository_impl.dart';
import 'package:taskflow/src/domain/entities/enums.dart';
import 'package:taskflow/src/domain/entities/task.dart';
import 'package:taskflow/src/domain/usecases/project_usecases.dart';

import 'helpers.dart';

/// Тесты бизнес-правил через слои Domain (UseCase) → Data (Repository,
/// DataSource) на реальной SQLite в памяти.
void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('Пользователи', () {
    test('создание и удаление пользователя', () async {
      final id = await env.user('Анна');
      expect((await env.users.getUsers()).value.single.name, 'Анна');
      (await env.users.deleteUser(id)).value;
      expect((await env.users.getUsers()).value, isEmpty);
    });

    test('email должен быть уникальным', () async {
      await env.user();
      final r = await env.createUser(name: 'B', email: 'U1@MAIL.com');
      expect(r.failure, isA<ValidationFailure>());
      expect(r.failure.message, 'Пользователь с таким email уже существует');
    });

    test('некорректный email отклоняется UseCase-ом', () async {
      final r = await env.createUser(name: 'A', email: 'bad');
      expect(r.failure, const ValidationFailure('Некорректный email'));
    });

    test('пустое имя отклоняется', () async {
      final r = await env.createUser(name: '  ', email: 'a@mail.com');
      expect(r.failure, isA<ValidationFailure>());
    });

    test('нельзя удалить пользователя с незавершёнными задачами', () async {
      final u = await env.user();
      final p = await env.project('P', ownerId: u);
      final t = (await env.createTask(
        title: 'T',
        projectId: p,
        assigneeId: u,
      )).value;
      expect((await env.users.deleteUser(u)).failure, isA<ValidationFailure>());
      (await env.tasks.changeStatus(t, TaskStatus.done)).value;
      (await env.users.deleteUser(u)).value; // теперь можно
      expect((await env.users.getUsers()).value, isEmpty);
      expect((await env.task(t))!.assigneeId, isNull);
    });
  });

  group('Проекты и участники', () {
    test('создание проекта с владельцем', () async {
      final u = await env.user();
      final p = await env.project('Alpha', ownerId: u);
      final members = (await env.projects.getMembers(p)).value;
      expect(members.single.role, MemberRole.owner);
    });

    test('пустое название проекта отклоняется', () async {
      final r = await env.createProject(name: ' ');
      expect(r.failure, isA<ValidationFailure>());
    });

    test('добавление участников и запрет дубликата', () async {
      final u = await env.user();
      final p = await env.project('Alpha');
      (await env.projects.addMember(projectId: p, userId: u)).value;
      expect(
        (await env.projects.addMember(projectId: p, userId: u)).failure,
        isA<ValidationFailure>(),
      );
      (await env.projects.setMemberRole(p, u, MemberRole.admin)).value;
      expect(
        (await env.projects.getMembers(p)).value.single.role,
        MemberRole.admin,
      );
    });

    test('GetAddableUsers возвращает только тех, кто ещё не в проекте', () async {
      final a = await env.user('A');
      await env.user('B');
      final p = await env.project('P', ownerId: a);
      final free = (await GetAddableUsersUseCase(env.projects, env.users)(
        p,
      )).value;
      expect(free.map((u) => u.name), ['B']);
    });
  });

  group('Задачи', () {
    late int user, project;
    setUp(() async {
      user = await env.user();
      project = await env.project('P', ownerId: user);
    });

    test('создание задачи пишет первую запись в историю', () async {
      final id = (await env.createTask(
        title: 'Task',
        projectId: project,
        assigneeId: user,
        actorId: user,
      )).value;
      final h = await env.history(id);
      expect(h, hasLength(1));
      expect(h.single.kind, HistoryKind.created);
      expect(h.single.oldStatus, isNull);
      expect(h.single.changedBy, user);
    });

    test('пустое название и отсутствие проекта отклоняются UseCase-ом', () async {
      expect(
        (await env.createTask(title: ' ', projectId: project)).failure,
        isA<ValidationFailure>(),
      );
      expect(
        (await env.createTask(title: 'X', projectId: null)).failure,
        const ValidationFailure('Выберите проект'),
      );
    });

    test('задача без существующего проекта не создаётся', () async {
      final r = await env.createTask(title: 'X', projectId: 9999);
      expect(r.failure, isA<ValidationFailure>());
    });

    test('исполнитель должен быть участником проекта', () async {
      final stranger = await env.user();
      expect(
        (await env.createTask(
          title: 'T',
          projectId: project,
          assigneeId: stranger,
        )).failure,
        isA<ValidationFailure>(),
      );
      final id = (await env.createTask(title: 'T', projectId: project)).value;
      expect(
        (await env.tasks.assignTask(id, stranger)).failure,
        isA<ValidationFailure>(),
      );
    });

    test('изменение статуса сохраняет историю', () async {
      final id = (await env.createTask(title: 'T', projectId: project)).value;
      (await env.tasks.changeStatus(
        id,
        TaskStatus.inProgress,
        actorId: user,
      )).value;
      (await env.tasks.changeStatus(id, TaskStatus.done, actorId: user)).value;
      final h = await env.history(id);
      expect(h.map((e) => e.newStatus), [
        TaskStatus.todo,
        TaskStatus.inProgress,
        TaskStatus.done,
      ]);
      expect(h[2].oldStatus, TaskStatus.inProgress);
      expect((await env.task(id))!.status, TaskStatus.done);
    });

    test('транзакция: ошибка истории откатывает создание задачи', () async {
      // actorId не существует -> FK в истории нарушен -> откат всей транзакции.
      // Ошибка БД превращается в Failure, а не в исключение.
      final r = await env.createTask(
        title: 'T',
        projectId: project,
        actorId: 424242,
      );
      expect(r.isLeft, isTrue);
      expect(await env.list(const TaskFilter()), isEmpty);
    });

    test('переназначение: проверка, смена и запись в историю', () async {
      final other = await env.user();
      (await env.projects.addMember(projectId: project, userId: other)).value;
      final id = (await env.createTask(
        title: 'T',
        projectId: project,
        assigneeId: user,
      )).value;
      (await env.tasks.assignTask(id, other, actorId: user)).value;
      expect((await env.task(id))!.assigneeId, other);
      final h = await env.history(id);
      expect(h.last.kind, HistoryKind.assignee);
      expect(h.last.note, contains('→'));
    });

    test('лимит: не более 3 незавершённых задач на один дедлайн', () async {
      final day = DateTime(2030, 5, 20, 10);
      for (var i = 0; i < kMaxTasksPerDeadline; i++) {
        (await env.createTask(
          title: 'T$i',
          projectId: project,
          assigneeId: user,
          deadline: day,
        )).value;
      }
      final extra = await env.createTask(
        title: 'extra',
        projectId: project,
        assigneeId: user,
        deadline: DateTime(2030, 5, 20, 18),
      );
      expect(extra.failure, isA<ValidationFailure>());
      // другой день — можно
      (await env.createTask(
        title: 'ok',
        projectId: project,
        assigneeId: user,
        deadline: DateTime(2030, 5, 21),
      )).value;
    });

    test('Undo возвращает предыдущий статус и не стирает историю', () async {
      final id = (await env.createTask(title: 'T', projectId: project)).value;
      (await env.tasks.changeStatus(id, TaskStatus.inProgress)).value;
      (await env.tasks.undoLastStatusChange(id)).value;
      expect((await env.task(id))!.status, TaskStatus.todo);
      final h = await env.history(id);
      expect(h.last.kind, HistoryKind.undo);
      expect(h, hasLength(3));
      // больше отменять нечего
      expect(
        (await env.tasks.undoLastStatusChange(id)).failure,
        isA<ValidationFailure>(),
      );
    });

    test('Soft Delete, корзина и восстановление', () async {
      final id = (await env.createTask(title: 'T', projectId: project)).value;
      (await env.tasks.softDelete(id)).value;
      expect(await env.list(const TaskFilter()), isEmpty);
      expect(await env.list(const TaskFilter(onlyDeleted: true)), hasLength(1));
      expect((await env.task(id))!.deletedAt, isNotNull);

      (await env.tasks.restore(id)).value;
      expect(await env.list(const TaskFilter()), hasLength(1));

      expect(
        (await env.tasks.deleteForever(id)).failure,
        isA<ValidationFailure>(),
      );
      (await env.tasks.softDelete(id)).value;
      (await env.tasks.deleteForever(id)).value;
      expect(await env.task(id), isNull);
    });

    test('фильтрация, сортировка, поиск и пагинация', () async {
      final base = DateTime(2030, 1, 1);
      for (var i = 0; i < 10; i++) {
        (await env.createTask(
          title: i.isEven ? 'Alpha $i' : 'Beta $i',
          description: 'desc $i',
          projectId: project,
          priority: i < 3 ? TaskPriority.high : TaskPriority.low,
          deadline: base.add(Duration(days: 10 - i)),
        )).value;
      }
      expect(await env.list(const TaskFilter()), hasLength(10));

      final high = await env.list(const TaskFilter(priority: TaskPriority.high));
      expect(high, hasLength(3));

      expect(await env.list(const TaskFilter(query: 'alpha')), hasLength(5));
      final byDesc = await env.list(const TaskFilter(query: 'desc 7'));
      expect(byDesc.single.task.title, 'Beta 7');

      final sorted = await env.list(
        const TaskFilter(sort: TaskSort.deadline, ascending: true),
      );
      expect(sorted.first.task.title, 'Beta 9'); // самый ранний дедлайн

      expect(await env.list(const TaskFilter(limit: 4)), hasLength(4));
      expect(
        await env.list(const TaskFilter(limit: 4, offset: 8)),
        hasLength(2),
      );
      expect(await env.list(const TaskFilter(assigneeId: 12345)), isEmpty);
    });

    test('фильтр по набору id (используется для избранного)', () async {
      final a = (await env.createTask(title: 'A', projectId: project)).value;
      (await env.createTask(title: 'B', projectId: project)).value;
      final c = (await env.createTask(title: 'C', projectId: project)).value;
      final res = await env.list(TaskFilter(taskIds: {a, c}));
      expect(res.map((e) => e.task.title).toSet(), {'A', 'C'});
      expect(await env.list(const TaskFilter(taskIds: {})), isEmpty);
    });
  });

  group('Комментарии', () {
    test(
      'добавление, запрет на несуществующую задачу, удаление автором',
      () async {
        final a = await env.user();
        final b = await env.user();
        final p = await env.project('P');
        final t = (await env.createTask(title: 'T', projectId: p)).value;

        final cid = (await env.addComment(
          taskId: t,
          authorId: a,
          body: ' hi ',
        )).value;
        expect(
          (await env.comments.getComments(t)).value.single.comment.body,
          'hi',
        );

        expect(
          (await env.addComment(taskId: 999, authorId: a, body: 'x')).failure,
          isA<ValidationFailure>(),
        );
        expect(
          (await env.addComment(taskId: t, authorId: null, body: 'x')).failure,
          isA<ValidationFailure>(),
        );
        expect(
          (await env.addComment(taskId: t, authorId: a, body: '  ')).failure,
          isA<ValidationFailure>(),
        );
        expect(
          (await env.comments.deleteComment(cid, requesterId: b)).failure,
          isA<ValidationFailure>(),
        );
        (await env.comments.deleteComment(cid, requesterId: a)).value;
        expect((await env.comments.getComments(t)).value, isEmpty);
      },
    );
  });

  group('Вложения', () {
    test('файл копируется в хранилище, в БД сохраняется путь', () async {
      final dir = await Directory.systemTemp.createTemp('taskflow_test_');
      addTearDown(() => dir.delete(recursive: true));
      final repo = AttachmentRepositoryImpl(
        AttachmentLocalDataSourceImpl(env.db, documentsDirectory: () async => dir),
      );
      final p = await env.project('P');
      final t = (await env.createTask(title: 'T', projectId: p)).value;

      final id = (await repo.addAttachment(
        taskId: t,
        fileName: 'a.txt',
        bytes: Uint8List.fromList([1, 2, 3]),
      )).value;
      final list = (await repo.getAttachments(t)).value;
      expect(list.single.fileName, 'a.txt');
      expect(File(list.single.filePath).readAsBytesSync(), [1, 2, 3]);

      (await repo.deleteAttachment(id)).value;
      expect((await repo.getAttachments(t)).value, isEmpty);
      expect(File(list.single.filePath).existsSync(), isFalse);
    });
  });

  group('Статистика', () {
    test('SQL-статистика считается корректно', () async {
      final u = await env.user('Ivan');
      final p1 = await env.project('P1', ownerId: u);
      await env.project('P2');
      final past = DateTime.now().subtract(const Duration(days: 3));

      final t1 = (await env.createTask(
        title: 'a',
        projectId: p1,
        assigneeId: u,
        priority: TaskPriority.high,
      )).value;
      (await env.createTask(
        title: 'b',
        projectId: p1,
        assigneeId: u,
        deadline: past,
      )).value;
      final t3 = (await env.createTask(
        title: 'c',
        projectId: p1,
        priority: TaskPriority.critical,
      )).value;
      final t4 = (await env.createTask(title: 'd', projectId: p1)).value;
      (await env.tasks.changeStatus(t1, TaskStatus.done)).value;
      (await env.tasks.changeStatus(t3, TaskStatus.cancelled)).value;
      (await env.tasks.softDelete(t4)).value; // в статистику не попадает

      final s = (await env.stats.getStats()).value;
      expect(s.projects, 2);
      expect(s.totalTasks, 3);
      expect(s.doneTasks, 1);
      expect(s.unfinishedTasks, 1);
      expect(s.overdueTasks, 1);
      expect(
        s.byPriority.firstWhere((e) => e.priority == TaskPriority.high).count,
        1,
      );
      expect(s.byAssignee.single.name, 'Ivan');
      expect(s.byAssignee.single.count, 2);
      final prog = s.projectProgress.firstWhere((e) => e.name == 'P1');
      expect(prog.percent, closeTo(100 / 3, 0.01));
      expect(s.projectProgress.firstWhere((e) => e.name == 'P2').percent, 0);
    });
  });

  group('Реактивность', () {
    test('watch() отдаёт новые данные при изменении БД', () async {
      final p = await env.project('P');
      final stream = env.tasks.watchTasks(const TaskFilter());
      final emissions = <int>[];
      final sub = stream.listen((l) => emissions.add(l.value.length));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      (await env.createTask(title: 'T', projectId: p)).value;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });
  });
}
