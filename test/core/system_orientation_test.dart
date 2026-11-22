import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/system_orientation.dart';

void main() {
  test('phone locks portrait, tablet is free', () {
    expect(preferredOrientationsFor(AppLayout.phone), [
      DeviceOrientation.portraitUp,
    ]);
    expect(preferredOrientationsFor(AppLayout.tablet), isEmpty);
    expect(preferredOrientationsFor(AppLayout.desktop), isEmpty);
  });

  test('app text scale is fixed at 1.0', () {
    expect(clampAppTextScaler(const TextScaler.linear(1.8)).scale(14), 14);
    expect(clampAppTextScaler(TextScaler.noScaling).scale(20), 20);
  });
}
