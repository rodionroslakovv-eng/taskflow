import 'dart:async';

extension SwitchMapExtension<T> on Stream<T> {
  /// Для каждого нового значения исходного потока отписывается от предыдущего
  /// внутреннего потока и подписывается на новый.
  Stream<R> switchMap<R>(Stream<R> Function(T value) mapper) {
    late final StreamController<R> controller;
    StreamSubscription<T>? outer;
    StreamSubscription<R>? inner;
    var outerDone = false;

    controller = StreamController<R>(
      onListen: () {
        outer = listen(
          (value) {
            inner?.cancel();
            inner = mapper(value).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                inner = null;
                if (outerDone) controller.close();
              },
            );
          },
          onError: controller.addError,
          onDone: () {
            outerDone = true;
            if (inner == null) controller.close();
          },
        );
      },
      onCancel: () async {
        await inner?.cancel();
        await outer?.cancel();
      },
    );
    return controller.stream;
  }
}
