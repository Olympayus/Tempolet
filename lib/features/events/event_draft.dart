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
    this.reminderOffsetMinutes,
    this.categoryId,
  });

  factory EventDraft.fromEvent(Event event) => EventDraft(
    title: event.title,
    note: event.note,
    kind: EventKind.fromDb(event.kind),
    date: event.date,
    startMinute: event.startMinute,
    endMinute: event.endMinute,
    reminderOffsetMinutes: event.reminderOffsetMinutes,
    categoryId: event.categoryId,
  );

  String title;
  String note;
  EventKind kind;
  DateTime date;
  int? startMinute;
  int? endMinute;

  /// null means "no notification" (see ledger ruling R6).
  int? reminderOffsetMinutes;

  String? categoryId;
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
      if (end == null || end <= start || end > 1440 || !inRange(end)) {
        errors.add(EventFormError.invalidRange);
      }
    }
  }

  return errors;
}
