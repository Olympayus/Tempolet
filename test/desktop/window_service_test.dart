import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/desktop/window_service.dart';

void main() {
  test('default window size is 1280x820', () {
    expect(defaultWindowSize, const Size(1280, 820));
  });

  test('minimum window size is 960x600', () {
    expect(minimumWindowSize, const Size(960, 600));
  });
}
