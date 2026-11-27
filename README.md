# TaskFlow — Clean Architecture

Flutter-приложение для управления проектами и задачами (Drift/SQLite, flutter_bloc, get_it).
Проект переведён на Clean Architecture (CPC 11).

## Структура

```
lib/
  main.dart                  точка входа, MultiBlocProvider, configureDependencies()
  constants/                 AppConstants, правила бизнес-логики, цвета
  components/                общие виджеты: EmptyState/LoadingView/ErrorView, диалоги, форматтеры
  models/                    Drift-таблицы, AppDatabase и DTO (Data Layer)
  core/
    di/                      GetIt: injection_container.dart
    error/                   Failure, исключения, guardCall/guardStream, failureMessage
    rest_client/             соответствие HTTP-статусов исключениям (задел под REST)
    utils/                   Either, Unit, switchMap
  src/
    domain/                  чистый Dart: entities, repositories (интерфейсы), usecases, validators
    data/                    datasources/local, mapper, repositories (реализации)
    presentation/            bloc (Cubit), pages, widgets
```

Зависимости направлены внутрь: `presentation → domain ← data`. Domain не знает про Flutter, Drift и SharedPreferences.

## Поток данных

UI → Cubit → UseCase → Repository (интерфейс) → RepositoryImpl → LocalDataSource → Drift/SharedPreferences.
Обратно: Drift-строки → mapper → Entity → `Either<Failure, T>` → состояние Cubit → UI.

Чтение — `Stream<Either<Failure, T>>` (Drift watch), запись — `Future<Either<Failure, T>>`.

## Обработка ошибок

Исключения Data Layer превращаются в `Failure` в одном месте — `core/error/error_handler.dart`.
До UI доходит только `Failure`; технические детали пишутся в лог.

| Ситуация                         | Исключение            | Failure             | Текст пользователю                 |
|----------------------------------|-----------------------|---------------------|------------------------------------|
| Нет сети / таймаут               | NetworkException      | NetworkFailure      | Нет подключения к интернету        |
| HTTP 400/422, нарушение правила  | ValidationException   | ValidationFailure   | сообщение правила                  |
| HTTP 401/403                     | UnauthorizedException | UnauthorizedFailure | Требуется авторизация              |
| HTTP 5xx                         | ServerException       | ServerFailure       | Ошибка сервера. Попробуйте позже   |
| Всё остальное                    | любое                 | UnknownFailure      | Произошла неизвестная ошибка       |

Приложение работает с локальной БД, поэтому реального REST-клиента нет; `core/rest_client/status_code_mapper.dart`
задаёт готовое правило для будущего Remote DataSource.

## Состояния экранов

`ViewState<T>`: Initial → Loading → Success / Empty / Error. `WatchCubit<T>` подписывается на поток UseCase,
умеет `retry()`; `ErrorView` показывает кнопку «Повторить».
`TaskListCubit` дополнительно хранит фильтр и пагинацию.

## DI

`core/di/injection_container.dart`: БД и SharedPreferences → DataSource → Repository → UseCase → Cubit.
Cubit с параметрами (id, фильтр) регистрируются через `registerFactoryParam`.
`configureDependencies` принимает подмену БД/хранилища для тестов.

## Новая функция: «Избранные задачи»

- звезда на карточке задачи и на экране задачи;
- экран «Избранное» (меню главного экрана);
- хранение id в SharedPreferences (`FavoritesLocalDataSource`);
- Domain: `FavoritesRepository`, `WatchFavoriteIdsUseCase`, `ToggleFavoriteUseCase`, `WatchFavoriteTasksUseCase`;
- Presentation: `FavoritesCubit`, `FavoriteTasksCubit`, `FavoritesPage`.

## Запуск

```
flutter pub get
dart run build_runner build   # только если менялись таблицы Drift
flutter run
flutter test
```

## Тесты

- `test/repository_test.dart` — бизнес-правила через UseCase/Repository на SQLite в памяти;
- `test/unit/` — Either/Failure, валидаторы, WatchCubit, избранное;
- `test/widget_test.dart` — экраны и сценарии (включая избранное);
- `test/migration_test.dart`, `test/performance_test.dart` — миграция схемы и индексы.
