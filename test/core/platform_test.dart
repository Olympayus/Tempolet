import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/platform.dart';

void main() {
  test('desktop targets are windows, macOS and linux', () {
    expect(isDesktopTarget(TargetPlatform.windows), isTrue);
    expect(isDesktopTarget(TargetPlatform.macOS), isTrue);
    expect(isDesktopTarget(TargetPlatform.linux), isTrue);
    expect(isDesktopTarget(TargetPlatform.android), isFalse);
    expect(isDesktopTarget(TargetPlatform.iOS), isFalse);
  });
}
