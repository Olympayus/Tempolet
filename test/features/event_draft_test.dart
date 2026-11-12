import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/features/events/event_draft.dart';

EventDraft _draft({
  String title = 'Meeting',
  EventKind kind = EventKind.reminder,
  int? startMinute = 540,
  int? endMinute,
}) {
  return EventDraft(
    title: title,
    kind: kind,
    date: DateTime(2026, 11, 11),
    startMinute: startMinute,
    endMinute: endMinute,
  );
}

void main() {
  test('valid reminder has no errors', () {
    expect(validateDraft(_draft()), isEmpty);
  });

  test('empty title is rejected', () {
    expect(validateDraft(_draft(title: '   ')),
        contains(EventFormError.emptyTitle));
  });

  test('reminder without a start is rejected', () {
    expect(validateDraft(_draft(startMinute: null)),
        contains(EventFormError.missingStart));
  });

  test('plan with end <= start is rejected', () {
    expect(
      validateDraft(
          _draft(kind: EventKind.plan, startMinute: 600, endMinute: 600)),
      contains(EventFormError.invalidRange),
    );
    expect(
      validateDraft(
          _draft(kind: EventKind.plan, startMinute: 600, endMinute: 540)),
      contains(EventFormError.invalidRange),
    );
  });

  test('valid plan has no errors', () {
    expect(
      validateDraft(
          _draft(kind: EventKind.plan, startMinute: 540, endMinute: 600)),
      isEmpty,
    );
  });

  test('out-of-range minutes are rejected', () {
    expect(
      validateDraft(_draft(startMinute: -5, kind: EventKind.reminder)),
      contains(EventFormError.invalidRange),
    );
    expect(
      validateDraft(_draft(
          kind: EventKind.plan, startMinute: 540, endMinute: 1500)),
      contains(EventFormError.invalidRange),
    );
  });

  test('EventKind maps to and from the database string', () {
    expect(EventKind.plan.dbValue, 'plan');
    expect(EventKind.reminder.dbValue, 'reminder');
    expect(EventKind.fromDb('plan'), EventKind.plan);
    expect(EventKind.fromDb('reminder'), EventKind.reminder);
  });
}
