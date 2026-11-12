import '../../data/database/database.dart';

enum EventKind {
  reminder,
  plan;

  String get dbValue => name;

  static EventKind fromDb(String value) =>
      value == 'plan' ? EventKind.plan : EventKind.reminder;
}

class EventDraft {
  EventDraft({
    this.title = '',
    this.note = '',
    this.kind = EventKind.reminder,
    required this.date,
    this.startMinute,
    this.endMinute,
    this.importance = 0,
    this.reminderOffsetMinutes,
  });

  factory EventDraft.fromEvent(Event event) => EventDraft(
        title: event.title,
        note: event.note,
        kind: EventKind.fromDb(event.kind),
        date: event.date,
        startMinute: event.startMinute,
        endMinute: event.endMinute,
        importance: event.importance,
        reminderOffsetMinutes: event.reminderOffsetMinutes,
      );

  String title;
  String note;
  EventKind kind;
  DateTime date;
  int? startMinute;
  int? endMinute;
  int importance;

  /// null means "no notification" (see ledger ruling R6).
  int? reminderOffsetMinutes;
}

enum EventFormError { emptyTitle, missingStart, invalidRange }

List<EventFormError> validateDraft(EventDraft draft) {
  final errors = <EventFormError>[];

  if (draft.title.trim().isEmpty) {
    errors.add(EventFormError.emptyTitle);
  }

  bool inRange(int minute) => minute >= 0 && minute <= 1440;

  final start = draft.startMinute;
  final end = draft.endMinute;

  if (start == null) {
    errors.add(EventFormError.missingStart);
  } else {
    if (!inRange(start)) errors.add(EventFormError.invalidRange);
    if (draft.kind == EventKind.plan) {
      if (end == null || end <= start || !inRange(end)) {
        errors.add(EventFormError.invalidRange);
      }
    }
  }

  return errors;
}
