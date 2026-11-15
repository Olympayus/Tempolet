import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/features/calendar/now_line.dart';
import 'package:tempolet/features/calendar/time_grid.dart';

void main() {
  test('time grid is 34px per hour starting at 07:00', () {
    expect(kHourHeight, 34);
    expect(kDefaultScrollOffset, 7 * 34);
    expect(minuteToY(90), 51);
  });

  test('yToMinute inverts the 34px scale', () {
    expect(yToMinute(34), 60);
    expect(yToMinute(51), 90);
    expect(yToMinute(0), 0);
  });

  test('axis gutter is 34px and is the HourGrid default', () {
    expect(kAxisGutter, 34);
    expect(const HourGrid().gutterWidth, kAxisGutter);
  });

  testWidgets('hour ticks use 11px sub-coloured text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HourGrid())),
    );

    final tick = tester.widget<Text>(find.text('07:00'));
    expect(tick.style?.fontSize, 11);
    expect(tick.style?.color, AppPalette.light.sub);
  });

  group('NowLine', () {
    testWidgets('draws a 5px accent dot and a 1px accent rule', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [NowLine(now: DateTime(2026, 11, 15, 9, 30))],
            ),
          ),
        ),
      );

      final row = tester.widget<Row>(
        find.descendant(of: find.byType(NowLine), matching: find.byType(Row)),
      );
      expect(row.children, hasLength(2));

      final accent = Theme.of(tester.element(find.byType(NowLine)))
          .colorScheme
          .primary;

      final dot = row.children.first as Container;
      expect(dot.constraints?.maxWidth, 5);
      expect(dot.constraints?.maxHeight, 5);
      final dotDecoration = dot.decoration! as BoxDecoration;
      expect(dotDecoration.shape, BoxShape.circle);
      expect(dotDecoration.color, accent);

      final rule = (row.children.last as Expanded).child as Container;
      expect(rule.constraints?.maxHeight, 1);
      expect(rule.color, accent);
    });

    testWidgets('positions itself at its own minute and the axis gutter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [NowLine(now: DateTime(2026, 11, 15, 9, 30))],
            ),
          ),
        ),
      );

      final positioned = tester.widget<Positioned>(
        find.descendant(
          of: find.byType(NowLine),
          matching: find.byType(Positioned),
        ),
      );
      expect(positioned.top, minuteToY(9 * 60 + 30));
      expect(positioned.left, kAxisGutter);
      expect(positioned.right, 0);
    });

    testWidgets('cancels its minute timer when disposed', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Stack(children: [NowLine()]))),
      );
      await tester.pump(const Duration(minutes: 1));

      // Replacing the tree disposes NowLine. If the periodic timer leaked,
      // flutter_test would fail the test with a pending-timer error.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });
}
