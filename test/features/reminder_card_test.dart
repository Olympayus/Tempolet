import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/category_repository.dart';
import 'package:tempolet/features/calendar/reminder_card.dart';

Event _event({String id = 'e1', bool isCompleted = false}) {
  final now = DateTime(2026, 11, 16);
  return Event(
    id: id,
    title: '寄快递',
    note: '',
    kind: 'reminder',
    date: now,
    startMinute: 540,
    importance: 0,
    isCompleted: isCompleted,
    completedAt: isCompleted ? now : null,
    notificationId: 1,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _app(Widget child) {
  return ProviderScope(
    overrides: [
      allCategoriesProvider.overrideWith(
        (ref) => Stream.value(const <Category>[]),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 240, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('onUndo replaces onComplete on a completed card', (tester) async {
    var completed = 0;
    var undone = 0;
    await tester.pumpWidget(
      _app(
        ReminderCard(
          event: _event(isCompleted: true),
          overdue: false,
          showCheckbox: true,
          onComplete: () async {
            completed++;
          },
          onUndo: () async {
            undone++;
          },
        ),
      ),
    );

    final circle = tester.widget<AppCheckCircle>(find.byType(AppCheckCircle));
    expect(circle.checked, isTrue);

    await tester.tap(find.byKey(const ValueKey('complete-e1')));
    await tester.pump();

    expect(undone, 1);
    expect(completed, 0);
    // Undo is immediate: the card never starts the completion fade.
    final cardOpacity = find
        .descendant(
          of: find.byType(ReminderCard),
          matching: find.byType(AnimatedOpacity),
        )
        .first;
    expect(tester.widget<AnimatedOpacity>(cardOpacity).opacity, 1);
  });

  testWidgets('progress and the overdue border reach the circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ReminderCard(
          event: _event(),
          overdue: true,
          showCheckbox: true,
          progress: 0.4,
          onUndo: () async {},
        ),
      ),
    );

    final circle = tester.widget<AppCheckCircle>(find.byType(AppCheckCircle));
    expect(circle.progress, 0.4);
    expect(circle.checked, isFalse);
    expect(circle.borderColor, AppPalette.light.danger);
  });

  testWidgets('titleBuilder replaces the card title and owns the strike', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ReminderCard(
          event: _event(isCompleted: true),
          overdue: false,
          showCheckbox: false,
          titleBuilder: (context, style) => Text(
            'custom',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ),
    );

    expect(find.text('custom'), findsOneWidget);
    expect(find.text('寄快递'), findsNothing);
    final custom = tester.widget<Text>(find.text('custom'));
    expect(custom.style?.color, AppPalette.light.sub);
    // The builder draws the strike-through itself.
    expect(custom.style?.decoration, isNull);
  });
}
