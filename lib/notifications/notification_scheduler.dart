import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/l10n/generated/app_localizations.dart';
import '../core/l10n/locale_controller.dart';
import '../core/utils/dates.dart';
import '../data/database/database.dart';
import '../data/repositories/event_repository.dart';
import '../features/settings/notification_prefs.dart';
import 'notification_payload.dart';
import 'notification_service.dart';

/// Receives notification taps and action payloads. Implemented by the app
/// shell; kept as an interface so the scheduler stays widget-free.
typedef NotificationTapHandler = Future<void> Function(String payload);

class NotificationScheduler {
  NotificationScheduler({
    required this.service,
    required this.repo,
    bool Function()? overdueSummaryEnabled,
    Locale Function()? locale,
  })  : _overdueSummaryEnabled = overdueSummaryEnabled ?? (() => true),
        _locale = locale ?? (() => const Locale('zh'));

  final NotificationService service;
  final EventRepository repo;
  final bool Function() _overdueSummaryEnabled;
  final Locale Function() _locale;

  static const snoozeDuration = Duration(minutes: 10);
  static const overdueSummaryId = 0x7FFFFFFF;

  /// Idempotent: always cancels the previous notification for this event
  /// before (re)scheduling, so repeated syncs never duplicate.
  Future<void> syncEvent(Event event) async {
    await service.cancel(event.notificationId);

    if (event.deletedAt != null || event.isCompleted) return;

    final start = event.startMinute;
    final offset = event.reminderOffsetMinutes;
    // Null offset means "no notification" — the editor writes the default
    // value at creation time (ledger ruling R6).
    if (start == null || offset == null) return;

    final at = DateTime(event.date.year, event.date.month, event.date.day)
        .add(Duration(minutes: start - offset));
    if (!at.isAfter(DateTime.now())) return;

    await service.schedule(
      ReminderNotification(
        id: event.notificationId,
        title: event.title,
        body: _body(event, offset),
        payload: eventPayload(event.id),
        at: at,
      ),
    );
  }

  Future<void> cancelEvent(Event event) => service.cancel(event.notificationId);

  Future<void> snooze(String eventId) async {
    final event = await repo.getById(eventId);
    if (event == null || event.isCompleted || event.deletedAt != null) return;

    await service.schedule(
      ReminderNotification(
        id: event.notificationId,
        title: event.title,
        body: _body(event, 0),
        payload: eventPayload(event.id),
        at: DateTime.now().add(snoozeDuration),
      ),
    );
  }

  /// Re-registers every future, unfinished event. Safe to run repeatedly
  /// (startup, timezone change, settings change).
  Future<void> reconcile() async {
    final events = await repo.upcomingFrom(dateOnly(DateTime.now()));
    for (final event in events) {
      await syncEvent(event);
    }
  }

  Future<void> maybeShowOverdueSummary(DateTime now) async {
    if (!_overdueSummaryEnabled()) return;

    final yesterday = dateOnly(now).subtract(const Duration(days: 1));
    final events = await repo.eventsOnDay(yesterday);
    final unfinished = events.where((e) => !e.isCompleted).length;
    if (unfinished == 0) return;

    final l10n = lookupAppLocalizations(_locale());
    await service.showNow(
      ReminderNotification(
        id: overdueSummaryId,
        title: l10n.notifOverdueTitle,
        body: l10n.notifOverdueBody(unfinished),
        payload: overdueSummaryPayload,
        at: now,
      ),
    );
  }

  String _body(Event event, int offsetMinutes) {
    final l10n = lookupAppLocalizations(_locale());
    final start = event.startMinute!;
    String hm(int minute) => DateFormat.Hm()
        .format(DateTime(2000, 1, 1, minute ~/ 60, minute % 60));

    final range = event.endMinute == null
        ? hm(start)
        : '${hm(start)}–${hm(event.endMinute!)}';
    final timeLabel = '${l10n.notifToday} $range';
    final remainingLabel = offsetMinutes > 0
        ? l10n.notifStartsIn(offsetMinutes)
        : l10n.notifStartingNow;

    return reminderBody(
      timeLabel: timeLabel,
      remainingLabel: remainingLabel,
      note: event.note,
    );
  }
}

/// Overridden in `main()` with the real FlutterLocalNotificationsService.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError(
    'notificationServiceProvider must be overridden at startup',
  ),
);

final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(
    service: ref.watch(notificationServiceProvider),
    repo: ref.watch(eventRepositoryProvider),
    overdueSummaryEnabled: () => ref.read(overdueSummaryEnabledProvider),
    locale: () =>
        ref.read(localeControllerProvider) ??
        (PlatformDispatcher.instance.locale),
  );
});
