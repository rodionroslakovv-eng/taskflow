/// Результат операции: либо ошибка ([Left]), либо значение ([Right]).
///
/// Собственная минимальная реализация, чтобы Domain Layer не зависел
/// от внешних функциональных библиотек.
sealed class Either<L, R> {
  const Either();

  bool get isLeft => this is Left<L, R>;
  bool get isRight => this is Right<L, R>;

  L? get leftOrNull => switch (this) {
    Left<L, R>(:final value) => value,
    Right<L, R>() => null,
  };

  R? get rightOrNull => switch (this) {
    Left<L, R>() => null,
    Right<L, R>(:final value) => value,
  };

  T fold<T>(T Function(L left) onLeft, T Function(R right) onRight) =>
      switch (this) {
        Left<L, R>(:final value) => onLeft(value),
        Right<L, R>(:final value) => onRight(value),
      };

  /// Преобразует значение справа, ошибку оставляет без изменений.
  Either<L, T> map<T>(T Function(R right) transform) => fold<Either<L, T>>(
    (l) => Left<L, T>(l),
    (r) => Right<L, T>(transform(r)),
  );
}

final class Left<L, R> extends Either<L, R> {
  const Left(this.value);
  final L value;

  @override
  bool operator ==(Object other) => other is Left<L, R> && other.value == value;

  @override
  int get hashCode => Object.hash('Left', value);
}

final class Right<L, R> extends Either<L, R> {
  const Right(this.value);
  final R value;

  @override
  bool operator ==(Object other) =>
      other is Right<L, R> && other.value == value;

  @override
  int get hashCode => Object.hash('Right', value);
}

/// «Пустое» значение для операций, которые ничего не возвращают.
final class Unit {
  const Unit._();
}

const Unit unit = Unit._();
