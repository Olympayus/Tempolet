import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/ui/app_icons.dart';

void main() {
  testWidgets('app icons paint at requested size without exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            AppIcon.calendar(size: 18),
            AppIcon.bell(size: 18),
            AppIcon.settings(size: 18),
            AppIcon.plus(size: 16),
            AppIcon.chevronLeft(size: 18),
            AppIcon.chevronRight(size: 18),
            AppIcon.check(size: 10),
            AppIcon.trash(size: 16),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('app icons take exactly size x size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            AppIcon.calendar(key: ValueKey('calendar'), size: 18),
            AppIcon.bell(key: ValueKey('bell'), size: 18),
            AppIcon.settings(key: ValueKey('settings'), size: 18),
            AppIcon.plus(key: ValueKey('plus'), size: 16),
            AppIcon.chevronLeft(key: ValueKey('chevronLeft'), size: 18),
            AppIcon.chevronRight(key: ValueKey('chevronRight'), size: 18),
            AppIcon.check(key: ValueKey('check'), size: 10),
            AppIcon.trash(key: ValueKey('trash'), size: 16),
          ],
        ),
      ),
    );

    const expected = {
      'calendar': 18.0,
      'bell': 18.0,
      'settings': 18.0,
      'plus': 16.0,
      'chevronLeft': 18.0,
      'chevronRight': 18.0,
      'check': 10.0,
      'trash': 16.0,
    };
    for (final entry in expected.entries) {
      expect(
        tester.getSize(find.byKey(ValueKey(entry.key))),
        Size(entry.value, entry.value),
        reason: '${entry.key} should paint at ${entry.value}x${entry.value}',
      );
    }
  });
}
