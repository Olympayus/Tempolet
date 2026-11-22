import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/ui/fitted_label.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/reminders/reminders_page.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

void main() {
  testWidgets('FittedLabel shrinks to its box and keeps every character', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 60,
            child: FittedLabel('Reminders & Plans'),
          ),
        ),
      ),
    );

    final box = tester.getSize(find.byType(FittedLabel));
    final text = tester.getSize(find.text('Reminders & Plans'));
    expect(box.width, 60);
    // The text keeps its intrinsic width and is painted scaled down, rather
    // than being cut with an ellipsis.
    expect(text.width, greaterThan(box.width));
    expect(
      tester.widget<Text>(find.text('Reminders & Plans')).overflow,
      isNot(TextOverflow.ellipsis),
    );
  });

  testWidgets('the phone reminders title reads in full in a narrow English '
      'header', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        todayProvider.overrideWithValue(DateTime(2026, 11, 16)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The tests run on a desktop host, which resolves to the desktop shell
    // unless forced; this test is about the phone header.
    debugLayoutOverride = AppLayout.phone;
    addTearDown(() => debugLayoutOverride = null);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: RemindersPage()),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();

    final title = find.byKey(const ValueKey('reminders-title'));
    final text = find.descendant(
      of: title,
      matching: find.text('Reminders & Plans'),
    );
    expect(text, findsOneWidget);
    expect(tester.widget<Text>(text).overflow, isNot(TextOverflow.ellipsis));

    // One line in a fixed 64 header; the label is painted smaller than its
    // intrinsic width rather than cut.
    expect(
      tester.getSize(find.byKey(const ValueKey('reminders-header'))).height,
      64,
    );
    expect(
      tester.getSize(text).width,
      greaterThan(tester.getSize(title).width),
    );

    // The filter controls keep full-size labels: with a longer translation
    // they stack instead of squeezing "Reminder" down.
    final filter = find.byKey(const ValueKey('reminders-filter'));
    final mode = find.byKey(const ValueKey('reminders-mode'));
    expect(
      tester.getTopLeft(mode).dy,
      greaterThan(tester.getBottomLeft(filter).dy - 1),
    );
    expect(tester.getSize(find.text('Reminder')).width, greaterThan(55));
  });
}
