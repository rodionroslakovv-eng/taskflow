import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/models/enums.dart';
import 'package:taskflow/models/models.dart';
import 'package:taskflow/repositories/task_repository.dart';

import 'helpers.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('Пользователи', () {
    test('создание и удаление пользователя', () async {
      final id = await env.user('Анна');
      expect((await env.users.getUsers()).single.name, 'Анна');
      await env.users.deleteUser(id);
      expect(await env.users.getUsers(), isEmpty);
    });

    test('email должен быть уникальным', () async {
      await env.users.createUser(name: 'A', email: 'a@mail.com');
      expect(
        () => env.users.createUser(name: 'B', email: 'A@MAIL.com'),
        throwsA(isA<TaskFlowException>()),
      );
    });

    test('некорректный email отклоняется', () {
      expect(
        () => env.users.createUser(name: 'A', email: 'bad'),
        throwsA(isA<TaskFlowException>()),
      );
    });

    test('нельзя удалить пользователя с незавершёнными задачами', () async {
      final u = await env.user();
      final p = await env.projects.createProject(name: 'P', ownerId: u);
      final t = await env.tasks.createTask(
        title: 'T',
        projectId: p,
        assigneeId: u,
      );
      await expectLater(
        env.users.deleteUser(u),
        throwsA(isA<TaskFlowException>()),
      );
      await env.tasks.changeStatus(t, TaskStatus.done);
      await env.users.deleteUser(u); // теперь можно
      expect(await env.users.getUser(u), isNull);
      expect((await env.tasks.getTask(t))!.assigneeId, isNull);
    });
  });

  group('Проекты и участники', () {
    test('создание проекта с владельцем', () async {
      final u = await env.user();
      final p = await env.projects.createProject(name: 'Alpha', ownerId: u);
      final members = await env.projects.getMembers(p);
      expect(members.single.member.role, MemberRole.owner);
    });

    test('добавление участников и запрет дубликата', () async {
      final u = await env.user();
      final p = await env.projects.createProject(name: 'Alpha');
      await env.projects.addMember(projectId: p, userId: u);
      expect(await env.projects.isMember(p, u), isTrue);
      await expectLater(
        env.projects.addMember(projectId: p, userId: u),
        throwsA(isA<TaskFlowException>()),
      );
      await env.projects.setRole(p, u, MemberRole.admin);
      expect(
        (await env.projects.getMembers(p)).single.member.role,
        MemberRole.admin,
      );
    });
  });

  group('Задачи', () {
    late int user, project;
    setUp(() async {
      user = await env.user();
      project = await env.projects.createProject(name: 'P', ownerId: user);
    });

    test('создание задачи пишет первую запись в историю', () async {
      final id = await env.tasks.createTask(
        title: 'Task',
        projectId: project,
        assigneeId: user,
        actorId: user,
      );
      final h = await env.tasks.getHistory(id);
      expect(h, hasLength(1));
      expect(h.single.kind, HistoryKind.created);
      expect(h.single.oldStatus, isNull);
      expect(h.single.changedBy, user);
    });

    test('задача без проекта не создаётся', () {
      expect(
        () => env.tasks.createTask(title: 'X', projectId: 9999),
        throwsA(isA<TaskFlowException>()),
      );
    });

    test('исполнитель должен быть участником проекта', () async {
      final stranger = await env.user();
      await expectLater(
        env.tasks.createTask(
          title: 'T',
          projectId: project,
          assigneeId: stranger,
        ),
        throwsA(isA<TaskFlowException>()),
      );
      final id = await env.tasks.createTask(title: 'T', projectId: project);
      await expectLater(
        env.tasks.assignTask(id, stranger),
        throwsA(isA<TaskFlowException>()),
      );
    });

    test('изменение статуса сохраняет историю', () async {
      final id = await env.tasks.createTask(title: 'T', projectId: project);
      await env.tasks.changeStatus(id, TaskStatus.inProgress, actorId: user);
      await env.tasks.changeStatus(id, TaskStatus.done, actorId: user);
      final h = await env.tasks.getHistory(id);
      expect(h.map((e) => e.newStatus), [
        TaskStatus.todo,
        TaskStatus.inProgress,
        TaskStatus.done,
      ]);
      expect(h[2].oldStatus, TaskStatus.inProgress);
      expect((await env.tasks.getTask(id))!.status, TaskStatus.done);
    });

    test('транзакция: ошибка истории откатывает создание задачи', () async {
      // actorId не существует -> FK в истории нарушен -> откат всей транзакции
      await expectLater(
        env.tasks.createTask(title: 'T', projectId: project, actorId: 424242),
        throwsA(anything),
      );
      expect(await env.tasks.getTasks(const TaskFilter()), isEmpty);
    });

    test('переназначение: проверка, смена и запись в историю', () async {
      final other = await env.user();
      await env.projects.addMember(projectId: project, userId: other);
      final id = await env.tasks.createTask(
        title: 'T',
        projectId: project,
        assigneeId: user,
      );
      await env.tasks.assignTask(id, other, actorId: user);
      expect((await env.tasks.getTask(id))!.assigneeId, other);
      final h = await env.tasks.getHistory(id);
      expect(h.last.kind, HistoryKind.assignee);
      expect(h.last.note, contains('→'));
    });

    test('лимит: не более 3 незавершённых задач на один дедлайн', () async {
      final day = DateTime(2030, 5, 20, 10);
      for (var i = 0; i < kMaxTasksPerDeadline; i++) {
        await env.tasks.createTask(
          title: 'T$i',
          projectId: project,
          assigneeId: user,
          deadline: day,
        );
      }
      await expectLater(
        env.tasks.createTask(
          title: 'extra',
          projectId: project,
          assigneeId: user,
          deadline: DateTime(2030, 5, 20, 18),
        ),
        throwsA(isA<TaskFlowException>()),
      );
      // другой день — можно
      await env.tasks.createTask(
        title: 'ok',
        projectId: project,
        assigneeId: user,
        deadline: DateTime(2030, 5, 21),
      );
    });

    test('Undo возвращает предыдущий статус и не стирает историю', () async {
      final id = await env.tasks.createTask(title: 'T', projectId: project);
      await env.tasks.changeStatus(id, TaskStatus.inProgress);
      await env.tasks.undoLastStatusChange(id);
      expect((await env.tasks.getTask(id))!.status, TaskStatus.todo);
      final h = await env.tasks.getHistory(id);
      expect(h.last.kind, HistoryKind.undo);
      expect(h, hasLength(3));
      // больше отменять нечего
      await expectLater(
        env.tasks.undoLastStatusChange(id),
        throwsA(isA<TaskFlowException>()),
      );
    });

    test('Soft Delete, корзина и восстановление', () async {
      final id = await env.tasks.createTask(title: 'T', projectId: project);
      await env.tasks.softDelete(id);
      expect(await env.tasks.getTasks(const TaskFilter()), isEmpty);
      expect(
        await env.tasks.getTasks(const TaskFilter(onlyDeleted: true)),
        hasLength(1),
      );
      expect((await env.tasks.getTask(id))!.deletedAt, isNotNull);

      await env.tasks.restore(id);
      expect(await env.tasks.getTasks(const TaskFilter()), hasLength(1));

      await expectLater(
        env.tasks.deleteForever(id),
        throwsA(isA<TaskFlowException>()),
      );
      await env.tasks.softDelete(id);
      await env.tasks.deleteForever(id);
      expect(await env.tasks.getTask(id), isNull);
    });

    test('фильтрация, сортировка, поиск и пагинация', () async {
      final base = DateTime(2030, 1, 1);
      for (var i = 0; i < 10; i++) {
        await env.tasks.createTask(
          title: i.isEven ? 'Alpha $i' : 'Beta $i',
          description: 'desc $i',
          projectId: project,
          priority: i < 3 ? TaskPriority.high : TaskPriority.low,
          deadline: base.add(Duration(days: 10 - i)),
        );
      }
      final all = await env.tasks.getTasks(const TaskFilter());
      expect(all, hasLength(10));

      final high = await env.tasks.getTasks(
        const TaskFilter(priority: TaskPriority.high),
      );
      expect(high, hasLength(3));

      final search = await env.tasks.getTasks(const TaskFilter(query: 'alpha'));
      expect(search, hasLength(5));
      final byDesc = await env.tasks.getTasks(
        const TaskFilter(query: 'desc 7'),
      );
      expect(byDesc.single.task.title, 'Beta 7');

      final sorted = await env.tasks.getTasks(
        const TaskFilter(sort: TaskSort.deadline, ascending: true),
      );
      expect(sorted.first.task.title, 'Beta 9'); // самый ранний дедлайн

      final page1 = await env.tasks.getTasks(const TaskFilter(limit: 4));
      final page3 = await env.tasks.getTasks(
        const TaskFilter(limit: 4, offset: 8),
      );
      expect(page1, hasLength(4));
      expect(page3, hasLength(2));

      final none = await env.tasks.getTasks(
        const TaskFilter(assigneeId: 12345),
      );
      expect(none, isEmpty);
    });
  });

  group('Комментарии', () {
    test(
      'добавление, запрет на несуществующую задачу, удаление автором',
      () async {
        final a = await env.user();
        final b = await env.user();
        final p = await env.projects.createProject(name: 'P');
        final t = await env.tasks.createTask(title: 'T', projectId: p);

        final cid = await env.comments.addComment(
          taskId: t,
          authorId: a,
          body: ' hi ',
        );
        expect((await env.comments.getComments(t)).single.comment.body, 'hi');

        await expectLater(
          env.comments.addComment(taskId: 999, authorId: a, body: 'x'),
          throwsA(isA<TaskFlowException>()),
        );
        await expectLater(
          env.comments.deleteComment(cid, requesterId: b),
          throwsA(isA<TaskFlowException>()),
        );
        await env.comments.deleteComment(cid, requesterId: a);
        expect(await env.comments.getComments(t), isEmpty);
      },
    );
  });

  group('Вложения', () {
    test('в БД сохраняется путь, а не содержимое', () async {
      final p = await env.projects.createProject(name: 'P');
      final t = await env.tasks.createTask(title: 'T', projectId: p);
      await env.attachments.addAttachment(
        taskId: t,
        fileName: 'a.txt',
        filePath: '/data/a.txt',
      );
      final list = await env.attachments.getAttachments(t);
      expect(list.single.filePath, '/data/a.txt');
    });
  });

  group('Статистика', () {
    test('SQL-статистика считается корректно', () async {
      final u = await env.user('Ivan');
      final p1 = await env.projects.createProject(name: 'P1', ownerId: u);
      await env.projects.createProject(name: 'P2');
      final past = DateTime.now().subtract(const Duration(days: 3));

      final t1 = await env.tasks.createTask(
        title: 'a',
        projectId: p1,
        assigneeId: u,
        priority: TaskPriority.high,
      );
      await env.tasks.createTask(
        title: 'b',
        projectId: p1,
        assigneeId: u,
        deadline: past,
      );
      final t3 = await env.tasks.createTask(
        title: 'c',
        projectId: p1,
        priority: TaskPriority.critical,
      );
      final t4 = await env.tasks.createTask(title: 'd', projectId: p1);
      await env.tasks.changeStatus(t1, TaskStatus.done);
      await env.tasks.changeStatus(t3, TaskStatus.cancelled);
      await env.tasks.softDelete(t4); // в статистику не попадает

      final s = await env.stats.getStats();
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
      final p = await env.projects.createProject(name: 'P');
      final stream = env.tasks.watchTasks(const TaskFilter());
      final emissions = <int>[];
      final sub = stream.listen((l) => emissions.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await env.tasks.createTask(title: 'T', projectId: p);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });
  });
}
