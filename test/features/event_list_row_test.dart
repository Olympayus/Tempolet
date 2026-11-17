import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/core/ui/app_list_checkbox.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/features/events/event_list_row.dart';

const _markerColor = Color(0xFFFF9500);

Event _event({
  String id = 'e1',
  required String title,
  String kind = 'reminder',
  DateTime? date,
  int? startMinute = 540,
  int? endMinute,
  bool isCompleted = false,
}) {
  final now = DateTime(2026, 11, 1);
  return Event(
    id: id,
    title: title,
    note: '',
    kind: kind,
    date: date ?? DateTime(2026, 11, 16),
    startMinute: startMinute,
    endMinute: endMinute,
    importance: 0,
    isCompleted: isCompleted,
    completedAt: isCompleted ? now : null,
    notificationId: 1,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets('plan and reminder titles align on the same x', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            EventListRow(
              event: _event(
                id: 'plan',
                title: 'Plan A',
                kind: 'plan',
                startMinute: 600,
                endMinute: 660,
              ),
              color: _markerColor,
              onToggleComplete: () {},
            ),
            EventListRow(
              event: _event(id: 'reminder', title: 'Reminder B'),
              color: _markerColor,
              onToggleComplete: () {},
            ),
          ],
        ),
      ),
    );

    final planX = tester.getTopLeft(find.text('Plan A')).dx;
    final remX = tester.getTopLeft(find.text('Reminder B')).dx;
    expect(planX, remX);
    expect(tester.getSize(find.byType(EventListRow).first).height, 46);
  });

  testWidgets('showDate prefixes the time with month and day', (tester) async {
    await tester.pumpWidget(
      _app(
        EventListRow(
          event: _event(title: 'Reminder B'),
          color: Colors.grey,
          showDate: true,
        ),
      ),
    );

    expect(find.text('11月16日 09:00'), findsOneWidget);
  });

  testWidgets('showDate adds the day in front of a plan time range', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EventListRow(
          event: _event(
            title: 'Plan A',
            kind: 'plan',
            startMinute: 600,
            endMinute: 660,
          ),
          color: Colors.grey,
          showDate: true,
        ),
      ),
    );

    expect(find.text('11月16日 10:00–11:00'), findsOneWidget);
  });

  testWidgets('plan rows draw the paper block behind the row', (tester) async {
    await tester.pumpWidget(
      _app(
        EventListRow(
          event: _event(
            title: 'Plan A',
            kind: 'plan',
            startMinute: 600,
            endMinute: 660,
          ),
          color: _markerColor,
        ),
      ),
    );

    final rowRect = tester.getRect(find.byType(EventListRow));
    final blockFinder = find.byKey(const ValueKey('event-list-row-block'));
    final blockRect = tester.getRect(blockFinder);
    expect(blockRect.left, rowRect.left);
    expect(blockRect.right, rowRect.right - 12);
    expect(blockRect.top, rowRect.top + 3);
    expect(blockRect.bottom, rowRect.bottom - 3);

    final decoration =
        tester.widget<Container>(blockFinder).decoration! as BoxDecoration;
    expect(decoration.color, AppPalette.light.block);
    expect(decoration.borderRadius, BorderRadius.circular(7));
  });

  testWidgets('reminder rows have no paper block', (tester) async {
    await tester.pumpWidget(
      _app(
        EventListRow(
          event: _event(title: 'Reminder B'),
          color: _markerColor,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('event-list-row-block')), findsNothing);
  });

  testWidgets('the marker slot holds a 2.5×16 bar for plans and a dot for '
      'reminders', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            EventListRow(
              event: _event(
                id: 'plan',
                title: 'Plan A',
                kind: 'plan',
                startMinute: 600,
                endMinute: 660,
              ),
              color: _markerColor,
            ),
            EventListRow(
              event: _event(id: 'reminder', title: 'Reminder B'),
              color: _markerColor,
            ),
          ],
        ),
      ),
    );

    final planFinder = find.byKey(const ValueKey('event-list-row-plan-marker'));
    expect(tester.getSize(planFinder), const Size(2.5, 16));
    final planDecoration =
        tester.widget<Container>(planFinder).decoration! as BoxDecoration;
    expect(planDecoration.color, _markerColor);
    expect(planDecoration.borderRadius, BorderRadius.circular(2));

    final reminderFinder = find.byKey(
      const ValueKey('event-list-row-reminder-marker'),
    );
    expect(tester.getSize(reminderFinder), const Size(6, 6));
    final reminderDecoration =
        tester.widget<Container>(reminderFinder).decoration! as BoxDecoration;
    expect(reminderDecoration.color, _markerColor);
    expect(reminderDecoration.shape, BoxShape.circle);
  });

  testWidgets('time text is right-aligned at row right minus 16', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            EventListRow(
              event: _event(
                id: 'plan',
                title: 'Plan A',
                kind: 'plan',
                startMinute: 600,
                endMinute: 660,
              ),
              color: _markerColor,
            ),
            EventListRow(
              event: _event(id: 'reminder', title: 'Reminder B'),
              color: _markerColor,
            ),
          ],
        ),
      ),
    );

    final rightEdge =
        tester.getRect(find.byType(EventListRow).first).right - 16;
    expect(
      tester.getRect(find.text('10:00–11:00')).right,
      moreOrLessEquals(rightEdge, epsilon: 0.01),
    );
    expect(
      tester.getRect(find.text('09:00')).right,
      moreOrLessEquals(rightEdge, epsilon: 0.01),
    );
  });

  testWidgets('completed events render a 13px strikethrough title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EventListRow(
          event: _event(title: 'Done thing', isCompleted: true),
          color: _markerColor,
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Done thing'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
    expect(title.style?.fontSize, 13);
    expect(title.style?.color, AppPalette.light.ink);
    expect(
      tester.widget<AppCheckCircle>(find.byType(AppCheckCircle)).checked,
      isTrue,
    );
  });

  testWidgets('tapping the row opens it and the circle toggles completion', (
    tester,
  ) async {
    var opened = 0;
    var toggled = 0;
    await tester.pumpWidget(
      _app(
        EventListRow(
          event: _event(title: 'Reminder B'),
          color: _markerColor,
          onTap: () => opened++,
          onToggleComplete: () => toggled++,
        ),
      ),
    );

    await tester.tap(find.text('Reminder B'));
    expect(opened, 1);
    expect(toggled, 0);

    await tester.tap(find.byType(AppCheckCircle));
    expect(opened, 1);
    expect(toggled, 1);
  });

  testWidgets(
    'selection mode swaps the completion circle for a list checkbox',
    (tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              EventListRow(
                event: _event(id: 'normal', title: 'Normal'),
                color: _markerColor,
                onToggleComplete: () {},
              ),
              EventListRow(
                event: _event(id: 'unchecked', title: 'Unchecked'),
                color: _markerColor,
                selectionChecked: false,
                onToggleSelection: () => toggled++,
              ),
              EventListRow(
                event: _event(id: 'checked', title: 'Checked'),
                color: _markerColor,
                selectionChecked: true,
                onToggleSelection: () => toggled++,
              ),
            ],
          ),
        ),
      );

      // Only the plain row shows the completion circle; both selection rows
      // show the square checkbox instead.
      expect(find.byType(AppCheckCircle), findsOneWidget);
      final checkboxes = find.byType(AppListCheckbox);
      expect(checkboxes, findsNWidgets(2));
      expect(
        tester.widgetList<AppListCheckbox>(checkboxes).map((c) => c.checked),
        [false, true],
      );

      await tester.tap(checkboxes.first);
      expect(toggled, 1);
    },
  );

  testWidgets('trailing renders after the time', (tester) async {
    await tester.pumpWidget(
      _app(
        EventListRow(
          event: _event(title: 'Reminder B'),
          color: _markerColor,
          trailing: const Text('TAIL'),
        ),
      ),
    );

    expect(find.text('TAIL'), findsOneWidget);
    expect(
      tester.getRect(find.text('TAIL')).left,
      greaterThan(tester.getRect(find.text('09:00')).right),
    );
  });

  testWidgets('titleBuilder replaces the default title in the same slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            EventListRow(
              event: _event(id: 'default', title: 'Default title'),
              color: _markerColor,
            ),
            EventListRow(
              event: _event(
                id: 'custom',
                title: 'Default title',
                isCompleted: true,
              ),
              color: _markerColor,
              titleBuilder: (context, style) => Text(
                'custom',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('custom'), findsOneWidget);
    // Only the row without a builder still paints its default title.
    expect(find.text('Default title'), findsOneWidget);

    final custom = tester.widget<Text>(find.text('custom'));
    expect(custom.style?.fontSize, 13);
    expect(custom.style?.color, AppPalette.light.ink);
    // The builder owns the strike-through; the row only supplies body + colour.
    expect(custom.style?.decoration, isNull);

    // The builder keeps the row's expanded one-line title slot instead of
    // shrinking to the text, so long titles still ellipsize.
    final defaultTitle = tester.getRect(find.text('Default title'));
    final customTitle = tester.getRect(find.text('custom'));
    expect(customTitle.left, defaultTitle.left);
    expect(customTitle.width, defaultTitle.width);
  });
}
