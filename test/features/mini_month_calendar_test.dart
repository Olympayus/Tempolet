import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/features/calendar/mini_month_calendar.dart';

final _today = DateTime(2026, 11, 16);
final _selected = DateTime(2026, 11, 18);

Widget _host({
  DateTime? month,
  DateTime? selected,
  DateTime? today,
  Set<DateTime> eventDays = const {},
  Map<DateTime, Color> eventDayColors = const {},
  Set<DateTime> planDays = const {},
  ValueChanged<DateTime>? onSelect,
  ValueChanged<DateTime>? onMonthChanged,
  double width = 180,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: MiniMonthCalendar(
          month: month ?? DateTime(2026, 11, 1),
          selected: selected ?? _selected,
          today: today ?? _today,
          eventDays: eventDays,
          eventDayColors: eventDayColors,
          planDays: planDays,
          onSelect: onSelect,
          onMonthChanged: onMonthChanged,
          width: width,
        ),
      ),
    ),
  );
}

BoxDecoration _decoration(WidgetTester tester, String key) {
  final container = tester.widget<Container>(find.byKey(ValueKey(key)));
  return container.decoration! as BoxDecoration;
}

Color _accent(WidgetTester tester) {
  return Theme.of(tester.element(find.byType(MiniMonthCalendar)))
      .colorScheme
      .primary;
}

void main() {
  testWidgets('today is a solid accent circle with white text', (tester) async {
    await tester.pumpWidget(_host());

    final accent = _accent(tester);
    final decoration = _decoration(tester, 'mini-day-bg-2026-11-16');
    expect(decoration.color, accent);
    expect(decoration.shape, BoxShape.circle);

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('mini-day-2026-11-16')),
        matching: find.text('16'),
      ),
    );
    expect(
      text.style?.color,
      Theme.of(tester.element(find.text('16'))).colorScheme.onPrimary,
    );
  });

  testWidgets('selected day uses accentTint and ink with no stroke', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    final accent = _accent(tester);
    final decoration = _decoration(tester, 'mini-day-bg-2026-11-18');
    expect(decoration.color, accent.withValues(alpha: .11));
    expect(decoration.border, isNull);

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('mini-day-2026-11-18')),
        matching: find.text('18'),
      ),
    );
    expect(text.style?.color, AppPalette.light.ink);
  });

  testWidgets('selected today keeps the solid today circle', (tester) async {
    await tester.pumpWidget(_host(selected: _today));

    final accent = _accent(tester);
    final decoration = _decoration(tester, 'mini-day-bg-2026-11-16');
    expect(decoration.color, accent);
    expect(decoration.shape, BoxShape.circle);
  });

  testWidgets('event days draw a 2px dot and plan days a 4px bar', (
    tester,
  ) async {
    const reminderColor = Color(0xFF34C759);
    const planColor = Color(0xFFFF9500);
    await tester.pumpWidget(
      _host(
        eventDays: {DateTime(2026, 11, 20), DateTime(2026, 11, 21)},
        eventDayColors: {
          DateTime(2026, 11, 20): reminderColor,
          DateTime(2026, 11, 21): planColor,
        },
        planDays: {DateTime(2026, 11, 21)},
      ),
    );

    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('mini-marker-2026-11-20')),
    );
    expect(dot.constraints?.maxWidth, 2);
    expect((dot.decoration! as BoxDecoration).color, reminderColor);

    final bar = tester.widget<Container>(
      find.byKey(const ValueKey('mini-marker-2026-11-21')),
    );
    expect(bar.constraints?.maxWidth, 4);
    expect((bar.decoration! as BoxDecoration).color, planColor);
  });

  testWidgets('day cells are keyed and report the tapped date', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(_host(onSelect: (day) => picked = day));

    expect(find.byKey(const ValueKey('mini-day-2026-11-20')), findsOneWidget);
    expect(find.byKey(const ValueKey('mini-day-2026-12-01')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mini-day-2026-11-20')));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2026, 11, 20));
  });

  testWidgets('month navigation buttons flip the month and notify', (
    tester,
  ) async {
    DateTime? changed;
    await tester.pumpWidget(_host(onMonthChanged: (month) => changed = month));

    await tester.tap(find.byKey(const ValueKey('mini-month-next')));
    await tester.pumpAndSettle();
    expect(changed, DateTime(2026, 12, 1));
    expect(find.text('2026年12月'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mini-month-prev')));
    await tester.pumpAndSettle();
    expect(find.text('2026年11月'), findsOneWidget);
  });

  testWidgets('a mouse wheel flips the month', (tester) async {
    DateTime? changed;
    await tester.pumpWidget(_host(onMonthChanged: (month) => changed = month));

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(MiniMonthCalendar)),
        scrollDelta: const Offset(0, 80),
      ),
    );
    await tester.pumpAndSettle();

    expect(changed, DateTime(2026, 12, 1));
    expect(find.text('2026年12月'), findsOneWidget);
    expect(find.byKey(const ValueKey('mini-day-2026-12-01')), findsOneWidget);
  });

  testWidgets('the year-month header opens a month picker', (tester) async {
    DateTime? changed;
    await tester.pumpWidget(_host(onMonthChanged: (month) => changed = month));

    await tester.tap(find.byKey(const ValueKey('mini-month-title')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mini-month-picker')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mini-picker-month-3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mini-month-picker')), findsNothing);
    expect(changed, DateTime(2026, 3, 1));
    expect(find.text('2026年3月'), findsOneWidget);
  });

  testWidgets('width is honoured', (tester) async {
    await tester.pumpWidget(_host(width: 204));
    expect(tester.getSize(find.byType(MiniMonthCalendar)).width, 204);
  });
}
