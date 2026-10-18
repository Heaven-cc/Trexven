import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/services/initial_load_timeout.dart';

void main() {
  test('Quiet live data does not time out after the first value', () async {
    final source = StreamController<int>();
    final errors = <Object>[];
    final values = <int>[];
    final subscription = withInitialLoadTimeout(
      source.stream,
      timeout: const Duration(milliseconds: 10),
    ).listen(values.add, onError: errors.add);
    source.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    source.add(2);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(values, [1, 2]);
    expect(errors, isEmpty);
    await subscription.cancel();
    await source.close();
  });
  test('A stream ending before initial data reports an error', () async {
    await expectLater(
      withInitialLoadTimeout(const Stream<int>.empty()),
      emitsError(isA<StateError>()),
    );
  });
}
