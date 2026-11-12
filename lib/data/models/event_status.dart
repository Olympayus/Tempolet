import '../database/database.dart';
import '../../core/utils/dates.dart';

enum EventStatus { pending, done, overdue }

/// An event is overdue only once its day has passed; today's items stay
/// pending until the day ends (design spec §3.2).
EventStatus eventStatus(Event e, DateTime today) {
  if (e.isCompleted) return EventStatus.done;
  final eventDay = dateOnly(e.date);
  final referenceDay = dateOnly(today);
  if (eventDay.isBefore(referenceDay)) return EventStatus.overdue;
  return EventStatus.pending;
}
