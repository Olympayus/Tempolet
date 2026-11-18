import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_page.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/sidebar.dart';
import 'package:tempolet/features/events/event_list_row.dart';
import 'package:tempolet/features/events/fields/segmented_date_field.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

/// Load the app fonts so width-sensitive sidebar assertions measure the same
/// glyph advances the desktop build uses (the default test font is much wider).
Future<void> _loadFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'));
  await inter.load();
  final noto = FontLoader('NotoSansSC')
    ..addFont(rootBundle.load('assets/fonts/NotoSansSC-Variable.ttf'));
  await noto.load();
  final material = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await material.load();
  for (final family in ['Lucide', 'packages/lucide_icons_flutter/Lucide']) {
    final lucide = FontLoader(family)
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await lucide.load();
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Widget _app(ProviderContainer container, {Locale locale = const Locale('zh')}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CalendarPage(),
    ),
  );
}

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _sidebar = ValueKey('calendar-sidebar');
const _header = ValueKey('sidebar-header');

/// Text inside the sidebar, ignoring the month grid that renders the same
/// events behind it.
Finder _sidebarText(String text) =>
    find.descendant(of: find.byKey(_sidebar), matching: find.text(text));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late SharedPreferences prefs;

  setUpAll(_loadFonts);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('defaults open on wide windows and persists the toggle', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.byKey(_sidebar), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sidebar-completed-link')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sidebar-add')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-sidebar-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(_sidebar), findsNothing);
    expect(prefs.getBool('sidebar_open'), isFalse);
  });

  testWidgets('is collapsed by default below 1180px', (tester) async {
    _useWindow(tester, const Size(1000, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.byKey(_sidebar), findsNothing);
    expect(prefs.getBool('sidebar_open'), isNull);
  });

  testWidgets('opens exactly at the 1180px breakpoint', (tester) async {
    _useWindow(tester, const Size(1180, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.byKey(_sidebar), findsOneWidget);
  });

  testWidgets('an explicit choice overrides the width default', (tester) async {
    _useWindow(tester, const Size(1000, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);
    expect(find.byKey(_sidebar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsOneWidget);
    expect(prefs.getBool('sidebar_open'), isTrue);

    // Crossing the breakpoint must not undo the user's explicit choice.
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsOneWidget);
  });

  testWidgets('day view hides the sidebar even when it is open', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);
    expect(find.byKey(_sidebar), findsOneWidget);

    container.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsNothing);
    expect(find.byKey(const ValueKey('calendar-sidebar-toggle')), findsNothing);

    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.month);
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsOneWidget);
  });

  testWidgets('sidebar is 300 wide with a single-row 60 header', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(tester.getSize(find.byType(CalendarSidebar)).width, 300);
    expect(tester.getSize(find.byKey(_header)).height, 60);
    expect(
      find.byKey(const ValueKey('sidebar-completed-link')),
      findsOneWidget,
    );
    // The header no longer carries any count.
    expect(
      find.descendant(
        of: find.byKey(_header),
        matching: find.textContaining('项'),
      ),
      findsNothing,
    );
    expect(_sidebarText('查看已完成'), findsOneWidget);
  });

  testWidgets('sidebar surface uses the side token', (tester) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final surface = tester.widget<Container>(
      find
          .descendant(of: find.byKey(_sidebar), matching: find.byType(Container))
          .first,
    );
    expect((surface.decoration! as BoxDecoration).color, AppPalette.light.side);
  });

  testWidgets('lists the selected day and opens rows and add in the editor', (
    tester,
  ) async {
    const longTitle = 'A very long standup title that must stay on one line';
    final reminder = await repo.create(
      title: longTitle,
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 540,
    );
    await repo.create(
      title: 'Deep work',
      kind: 'plan',
      date: DateTime(2026, 11, 12),
      startMinute: 600,
      endMinute: 660,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(_sidebarText('11月12日'), findsOneWidget);
    expect(_sidebarText('周四'), findsOneWidget);
    expect(_sidebarText('计划'), findsOneWidget);
    expect(_sidebarText('提醒'), findsOneWidget);
    expect(_sidebarText('09:00'), findsOneWidget);
    expect(_sidebarText('10:00–11:00'), findsOneWidget);
    expect(find.byKey(ValueKey('sidebar-row-${reminder.id}')), findsOneWidget);
    expect(
      find.byKey(ValueKey('sidebar-complete-${reminder.id}')),
      findsOneWidget,
    );

    final title = tester.widget<Text>(_sidebarText(longTitle));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);

    // Tapping a row edits the existing event.
    await tester.tap(find.byKey(ValueKey('sidebar-row-${reminder.id}')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('editor-title')), findsOneWidget);
    expect(
      tester
          .widget<SegmentedDateField>(find.byKey(const ValueKey('editor-date')))
          .value,
      DateTime(2026, 11, 12),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-title')))
          .controller
          ?.text,
      longTitle,
    );

    await tester.tap(find.text('取消'));
    await _settle(tester);

    // The footer button creates a new item on the selected day.
    await tester.tap(find.byKey(const ValueKey('sidebar-add')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('editor-title')), findsOneWidget);
    expect(
      tester
          .widget<SegmentedDateField>(find.byKey(const ValueKey('editor-date')))
          .value,
      DateTime(2026, 11, 12),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-title')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('groups plans before reminders with 34 headers and a 16 gap', (
    tester,
  ) async {
    final lateReminder = await repo.create(
      title: 'Late reminder',
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 660,
    );
    final earlyReminder = await repo.create(
      title: 'Early reminder',
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 540,
    );
    await repo.create(
      title: 'Deep work',
      kind: 'plan',
      date: DateTime(2026, 11, 12),
      startMinute: 600,
      endMinute: 720,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final planGroup = find.byKey(const ValueKey('sidebar-group-plan'));
    final reminderGroup = find.byKey(const ValueKey('sidebar-group-reminder'));
    expect(planGroup, findsOneWidget);
    expect(reminderGroup, findsOneWidget);

    // Plans come first even though the plan starts after the early reminder.
    expect(
      tester.getRect(planGroup).bottom + 16,
      closeTo(tester.getRect(reminderGroup).top, 0.01),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('sidebar-group-title-plan')))
          .height,
      34,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('sidebar-group-title-reminder')))
          .height,
      34,
    );

    // Inside a group rows stay in time order.
    expect(
      tester
          .getTopLeft(find.byKey(ValueKey('sidebar-row-${earlyReminder.id}')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(ValueKey('sidebar-row-${lateReminder.id}')))
            .dy,
      ),
    );

    final planTitle = tester.widget<Text>(
      find.descendant(of: planGroup, matching: find.text('计划')),
    );
    expect(planTitle.style?.fontSize, 15);
    expect(planTitle.style?.fontWeight, FontWeight.w600);
    final planCount = tester.widget<Text>(
      find.descendant(of: planGroup, matching: find.text('1')),
    );
    expect(planCount.style?.fontSize, 11);
    expect(planCount.style?.color, AppPalette.light.subMuted);
  });

  testWidgets('empty groups are not drawn', (tester) async {
    await repo.create(
      title: 'Only reminder',
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 540,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('sidebar-group-reminder')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sidebar-group-plan')), findsNothing);
    expect(_sidebarText('计划'), findsNothing);
  });

  testWidgets('rows reuse EventListRow and keep the sidebar keys', (
    tester,
  ) async {
    final reminder = await repo.create(
      title: 'Call back',
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 750,
    );
    await repo.create(
      title: 'Deep work',
      kind: 'plan',
      date: DateTime(2026, 11, 12),
      startMinute: 600,
      endMinute: 660,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.byType(EventListRow), findsNWidgets(2));
    final row = find.byKey(ValueKey('sidebar-row-${reminder.id}'));
    expect(tester.getSize(row).height, 46);
    expect(
      find.byKey(ValueKey('sidebar-complete-${reminder.id}')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('event-list-row-block')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-list-row-plan-marker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('event-list-row-reminder-marker')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('sidebar-add'))).height,
      46,
    );
  });

  testWidgets('english header fits 300px without ellipsis or clipping', (
    tester,
  ) async {
    await repo.create(
      title: 'Standup',
      kind: 'reminder',
      date: DateTime(2026, 11, 17),
      startMinute: 570,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 17));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container, locale: const Locale('en')));
    await _settle(tester);

    final header = find.byKey(_header);
    // The 1px left border sits inside the 300px sidebar.
    expect(tester.getSize(header).width, 299);
    final headerRect = tester.getRect(header);
    final dateFinder = find.descendant(
      of: header,
      matching: find.text('Nov 17, 2026'),
    );
    final weekdayFinder = find.descendant(
      of: header,
      matching: find.text('Tue'),
    );
    final linkFinder = find.byKey(const ValueKey('sidebar-completed-link'));
    final completedFinder = find.descendant(
      of: linkFinder,
      matching: find.text('Completed'),
    );
    expect(dateFinder, findsOneWidget);
    expect(weekdayFinder, findsOneWidget);
    expect(completedFinder, findsOneWidget);
    expect(tester.getSize(linkFinder).height, 26);

    for (final finder in [dateFinder, weekdayFinder, completedFinder]) {
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(paragraph.didExceedMaxLines, isFalse);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(headerRect.left));
      expect(rect.right, lessThanOrEqualTo(headerRect.right));
    }
    expect(tester.takeException(), isNull);

    // The binding design sizes the worst case with the full weekday name.
    final tuesday = TextPainter(
      text: const TextSpan(text: 'Tuesday', style: AppTextStyles.secondary),
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(tuesday.dispose);
    final minimumWidth =
        16 +
        tester.getSize(dateFinder).width +
        8 +
        tuesday.width +
        8 +
        tester.getSize(linkFinder).width +
        16;
    expect(minimumWidth, lessThanOrEqualTo(headerRect.width));
  });

  testWidgets('shows a two-part empty state 16 below the header', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(_sidebarText('无安排'), findsOneWidget);
    expect(_sidebarText('添加提醒或计划，开始这一天。'), findsOneWidget);

    final headerRect = tester.getRect(find.byKey(_header));
    final titleRect = tester.getRect(_sidebarText('无安排'));
    expect(titleRect.top - headerRect.bottom, 16);

    final title = tester.widget<Text>(_sidebarText('无安排'));
    expect(title.style?.fontSize, 14);
    expect(title.style?.fontWeight, FontWeight.w500);
    expect(title.style?.color, AppPalette.light.sub);
    final hint = tester.widget<Text>(_sidebarText('添加提醒或计划，开始这一天。'));
    expect(hint.style?.fontSize, 13);
    expect(hint.style?.color, AppPalette.light.subWeak);
  });

  testWidgets('checking a row completes the event and removes it', (
    tester,
  ) async {
    final event = await repo.create(
      title: 'Call back',
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 750,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('sidebar-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 150));
    await _settle(tester);

    expect(find.byKey(ValueKey('sidebar-row-${event.id}')), findsNothing);
    final rows = await tester.runAsync(() => db.select(db.events).get());
    expect(rows!.single.isCompleted, isTrue);
  });

  testWidgets('dismissing during the fade still writes the completion', (
    tester,
  ) async {
    final event = await repo.create(
      title: 'Call back',
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 750,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('sidebar-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 20));
    // Tear the page down before the 120ms fade finishes; the write must still
    // happen without touching `ref` after disposal.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    final rows = await tester.runAsync(() => db.select(db.events).get());
    expect(rows!.single.isCompleted, isTrue);
  });
}
