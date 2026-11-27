import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/either.dart';
import '../../../domain/entities/attachment.dart';
import '../../../domain/entities/comment.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/history.dart';
import '../../../domain/entities/project.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/usecases/attachment_usecases.dart';
import '../../../domain/usecases/comment_usecases.dart';
import '../../../domain/usecases/project_usecases.dart';
import '../../../domain/usecases/task_usecases.dart';
import '../common/watch_cubit.dart';

/// Карточка задачи и действия над ней.
class TaskDetailCubit extends WatchCubit<TaskItem?> {
  TaskDetailCubit(
    this.taskId,
    this._watchTask,
    this._changeStatus,
    this._changePriority,
    this._assign,
    this._undo,
    this._softDelete,
    this._getMembers,
  );

  final int taskId;
  final WatchTaskUseCase _watchTask;
  final ChangeTaskStatusUseCase _changeStatus;
  final ChangeTaskPriorityUseCase _changePriority;
  final AssignTaskUseCase _assign;
  final UndoStatusChangeUseCase _undo;
  final SoftDeleteTaskUseCase _softDelete;
  final GetProjectMembersUseCase _getMembers;

  @override
  Stream<Either<Failure, TaskItem?>> watch() => _watchTask(taskId);

  Future<Either<Failure, Unit>> changeStatus(TaskStatus s, {int? actorId}) =>
      _changeStatus(taskId, s, actorId: actorId);

  Future<Either<Failure, Unit>> changePriority(TaskPriority p) =>
      _changePriority(taskId, p);

  Future<Either<Failure, Unit>> assign(int? userId, {int? actorId}) =>
      _assign(taskId, userId, actorId: actorId);

  Future<Either<Failure, Unit>> undo({int? actorId}) =>
      _undo(taskId, actorId: actorId);

  Future<Either<Failure, Unit>> moveToTrash() => _softDelete(taskId);

  Future<Either<Failure, List<ProjectMember>>> projectMembers(int projectId) =>
      _getMembers(projectId);
}

class TaskHistoryCubit extends WatchCubit<List<HistoryItem>> {
  TaskHistoryCubit(this.taskId, this._watchHistory);
  final int taskId;
  final WatchTaskHistoryUseCase _watchHistory;

  @override
  Stream<Either<Failure, List<HistoryItem>>> watch() => _watchHistory(taskId);
}

/// Последнее изменение статуса, которое можно отменить (Empty — отменять нечего).
class LastUndoableCubit extends WatchCubit<HistoryEntry?> {
  LastUndoableCubit(this.taskId, this._watchLast);
  final int taskId;
  final WatchLastUndoableUseCase _watchLast;

  @override
  Stream<Either<Failure, HistoryEntry?>> watch() => _watchLast(taskId);
}

class CommentsCubit extends WatchCubit<List<CommentItem>> {
  CommentsCubit(this.taskId, this._watch, this._add, this._delete);

  final int taskId;
  final WatchCommentsUseCase _watch;
  final AddCommentUseCase _add;
  final DeleteCommentUseCase _delete;

  @override
  Stream<Either<Failure, List<CommentItem>>> watch() => _watch(taskId);

  Future<Either<Failure, Unit>> add({
    required int? authorId,
    required String body,
  }) async => (await _add(
    taskId: taskId,
    authorId: authorId,
    body: body,
  )).map((_) => unit);

  Future<Either<Failure, Unit>> delete(int commentId, {required int requesterId}) =>
      _delete(commentId, requesterId: requesterId);
}

class AttachmentsCubit extends WatchCubit<List<Attachment>> {
  AttachmentsCubit(this.taskId, this._watch, this._add, this._delete);

  final int taskId;
  final WatchAttachmentsUseCase _watch;
  final AddAttachmentUseCase _add;
  final DeleteAttachmentUseCase _delete;

  @override
  Stream<Either<Failure, List<Attachment>>> watch() => _watch(taskId);

  Future<Either<Failure, Unit>> add(String fileName, Uint8List bytes) async =>
      (await _add(taskId: taskId, fileName: fileName, bytes: bytes)).map(
        (_) => unit,
      );

  Future<Either<Failure, Unit>> delete(int id) => _delete(id);
}

/// Корзина: задачи с заполненным deletedAt.
class TrashCubit extends WatchCubit<List<TaskItem>> {
  TrashCubit(this._watchTasks, this._restore, this._deleteForever);

  final WatchTasksUseCase _watchTasks;
  final RestoreTaskUseCase _restore;
  final DeleteTaskForeverUseCase _deleteForever;

  @override
  Stream<Either<Failure, List<TaskItem>>> watch() =>
      _watchTasks(const TaskFilter(onlyDeleted: true));

  Future<Either<Failure, Unit>> restore(int id) => _restore(id);
  Future<Either<Failure, Unit>> deleteForever(int id) => _deleteForever(id);
}

class TaskFormState extends Equatable {
  const TaskFormState({
    this.projects = const [],
    this.members = const [],
    this.saving = false,
    this.loadFailure,
  });

  final List<Project> projects;
  final List<ProjectMember> members;
  final bool saving;
  final Failure? loadFailure;

  TaskFormState copyWith({
    List<Project>? projects,
    List<ProjectMember>? members,
    bool? saving,
    Failure? loadFailure,
  }) => TaskFormState(
    projects: projects ?? this.projects,
    members: members ?? this.members,
    saving: saving ?? this.saving,
    loadFailure: loadFailure,
  );

  @override
  List<Object?> get props => [projects, members, saving, loadFailure];
}

/// Форма создания / редактирования задачи.
class TaskFormCubit extends Cubit<TaskFormState> {
  TaskFormCubit(
    this._getProjects,
    this._getMembers,
    this._createTask,
    this._updateTask,
  ) : super(const TaskFormState());

  final GetProjectsUseCase _getProjects;
  final GetProjectMembersUseCase _getMembers;
  final CreateTaskUseCase _createTask;
  final UpdateTaskUseCase _updateTask;

  Future<void> loadProjects() async {
    final result = await _getProjects();
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(loadFailure: f)),
      (list) => emit(state.copyWith(projects: list)),
    );
  }

  Future<void> loadMembers(int? projectId) async {
    if (projectId == null) {
      emit(state.copyWith(members: const []));
      return;
    }
    final result = await _getMembers(projectId);
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(loadFailure: f)),
      (list) => emit(state.copyWith(members: list)),
    );
  }

  Future<Either<Failure, Unit>> create({
    required String title,
    required String description,
    required int? projectId,
    required int? assigneeId,
    required TaskPriority priority,
    DateTime? deadline,
    int? actorId,
  }) => _save(
    () async => (await _createTask(
      title: title,
      description: description,
      projectId: projectId,
      assigneeId: assigneeId,
      priority: priority,
      deadline: deadline,
      actorId: actorId,
    )).map((_) => unit),
  );

  Future<Either<Failure, Unit>> update(
    int taskId, {
    required String title,
    required String description,
    required TaskPriority priority,
    DateTime? deadline,
  }) => _save(
    () => _updateTask(
      taskId,
      title: title,
      description: description,
      priority: priority,
      deadline: deadline,
    ),
  );

  Future<Either<Failure, Unit>> _save(
    Future<Either<Failure, Unit>> Function() action,
  ) async {
    emit(state.copyWith(saving: true));
    final result = await action();
    if (!isClosed) emit(state.copyWith(saving: false));
    return result;
  }
}
