import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/events/event_editor_sheet.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

late AppDatabase _db;
late ProviderContainer _container;
late EventRepository _repo;

Future<void> _init() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  _db = AppDatabase(NativeDatabase.memory());
  _repo = EventRepository(_db);
  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(_db),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
    ],
  );
  addTearDown(() async {
    _container.dispose();
    await _db.close();
  });
}

void _useLayout(WidgetTester tester, AppLayout layout, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugLayoutOverride = layout;
  addTearDown(() => debugLayoutOverride = null);
}

Future<void> _pumpEditor(WidgetTester tester, {Event? existing}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEventEditor(context, existing: existing),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(_init);

  Future<Event> seed() => _repo.create(
    title: 'Title',
    kind: 'reminder',
    date: DateTime(2026, 11, 16),
    startMinute: 540,
    reminderOffsetMinutes: 0,
  );

  testWidgets('closing an unchanged editor does not ask', (tester) async {
    final event = await seed();
    await _pumpEditor(tester, existing: event);

    await tester.tap(find.byKey(const ValueKey('editor-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-discard-confirm')), findsNothing);
    expect(find.byType(EventEditorDialog), findsNothing);
  });

  testWidgets('closing a changed editor asks first', (tester) async {
    final event = await seed();
    await _pumpEditor(tester, existing: event);

    await tester.enterText(find.byKey(const ValueKey('editor-title')), '改过的标题');
    await tester.tap(find.byKey(const ValueKey('editor-close')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('editor-discard-confirm')),
      findsOneWidget,
    );
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    expect(find.byType(EventEditorDialog), findsNothing);
  });

  testWidgets('phone fields are 40 high, tablet 42', (tester) async {
    final event = await seed();

    _useLayout(tester, AppLayout.phone, const Size(375, 812));
    await _pumpEditor(tester, existing: event);
    expect(
      tester.getSize(find.byKey(const ValueKey('editor-title'))).height,
      40,
    );

    debugLayoutOverride = AppLayout.tablet;
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pumpEditor(tester, existing: event);
    expect(
      tester.getSize(find.byKey(const ValueKey('editor-title'))).height,
      42,
    );
  });

  testWidgets('phone date field opens a bottom sheet', (tester) async {
    final event = await seed();
    _useLayout(tester, AppLayout.phone, const Size(375, 812));
    await _pumpEditor(tester, existing: event);

    await tester.ensureVisible(find.byKey(const ValueKey('date-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('date-calendar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('date-picker-sheet')), findsOneWidget);
  });
}
