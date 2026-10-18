import 'dart:async';

/// Bound the first load without treating a quiet realtime subscription as an error.
Stream<T> withInitialLoadTimeout<T>(
  Stream<T> source, {
  Duration timeout = const Duration(seconds: 20),
}) {
  var waiting = true;
  return source
      .transform(
        StreamTransformer<T, T>.fromHandlers(
          handleData: (value, sink) {
            waiting = false;
            sink.add(value);
          },
          handleError: (error, stack, sink) {
            waiting = false;
            sink.addError(error, stack);
          },
          handleDone: (sink) {
            if (waiting)
              sink.addError(StateError('The initial load ended without data.'));
            sink.close();
          },
        ),
      )
      .timeout(
        timeout,
        onTimeout: (sink) {
          if (waiting) {
            waiting = false;
            sink.addError(
              TimeoutException('Loading took too long. Please retry.', timeout),
            );
          }
        },
      );
}
