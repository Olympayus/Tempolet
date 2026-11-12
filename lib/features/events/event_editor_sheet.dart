import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/repositories/event_repository.dart';
import '../settings/notification_prefs.dart';
import 'event_draft.dart';

/// Opens the shared event editor. One component serves all three entry
/// points: tap (reminder at a time), drag (plan over a range), and "+" (from
/// scratch) — they differ only in what they prefill.
Future<Event?> showEventEditor(
  BuildContext context, {
  Event? existing,
  DateTime? date,
  int? startMinute,
  int? endMinute,
  EventKind? initialKind,
}) {
  return showDialog<Event>(
    context: context,
    builder: (context) => EventEditorDialog(
      existing: existing,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      initialKind: initialKind,
    ),
  );
}

class EventEditorDialog extends ConsumerStatefulWidget {
  const EventEditorDialog({
    super.key,
    this.existing,
    this.date,
    this.startMinute,
    this.endMinute,
    this.initialKind,
  });

  final Event? existing;
  final DateTime? date;
  final int? startMinute;
  final int? endMinute;
  final EventKind? initialKind;

  @override
  ConsumerState<EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends ConsumerState<EventEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late EventKind _kind;
  late DateTime _date;
  int? _start;
  int? _end;
  late int _importance;
  int? _offset;
  List<EventFormError> _errors = const [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _note = TextEditingController(text: existing?.note ?? '');
    _kind = existing != null
        ? EventKind.fromDb(existing.kind)
        : widget.initialKind ?? EventKind.reminder;
    _date = dateOnly(existing?.date ?? widget.date ?? DateTime.now());
    _start = existing?.startMinute ?? widget.startMinute;
    _end = existing?.endMinute ?? widget.endMinute;
    _importance = existing?.importance ?? 0;
    _offset = existing != null
        ? existing.reminderOffsetMinutes
        : ref.read(defaultReminderOffsetProvider);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _stepStart(int delta) {
    setState(() {
      final base = _start ?? 9 * 60;
      _start = snapMinutes(base + delta).clamp(0, 1440);
      if (_kind == EventKind.plan) {
        if (_end == null || _end! <= _start!) {
          _end = snapMinutes(_start! + 30).clamp(0, 1440);
        }
      }
    });
  }

  void _stepEnd(int delta) {
    setState(() {
      final base = _end ?? (_start ?? 9 * 60) + 60;
      _end = snapMinutes(base + delta).clamp(0, 1440);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final initial = current == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : minutesToTimeOfDay(current);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final minutes = snapMinutes(timeToMinutes(picked));
    setState(() {
      if (isStart) {
        _start = minutes;
        if (_kind == EventKind.plan && (_end == null || _end! <= minutes)) {
          _end = snapMinutes(minutes + 30).clamp(0, 1440);
        }
      } else {
        _end = minutes;
      }
    });
  }

  String _format(int? minute) =>
      minute == null ? '--:--' : DateFormat.Hm().format(
            DateTime(2000, 1, 1, minute ~/ 60, minute % 60),
          );

  Future<void> _save() async {
    final draft = EventDraft(
      title: _title.text,
      note: _note.text,
      kind: _kind,
      date: _date,
      startMinute: _start,
      endMinute: _kind == EventKind.plan ? _end : null,
      importance: _importance,
      reminderOffsetMinutes: _offset,
    );
    final errors = validateDraft(draft);
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    final repo = ref.read(eventRepositoryProvider);
    final existing = widget.existing;
    Event result;
    if (existing != null) {
      final updated = existing.copyWith(
        title: _title.text.trim(),
        note: _note.text,
        kind: _kind.dbValue,
        date: dateOnly(_date),
        startMinute: Value(_start),
        endMinute: Value(_kind == EventKind.plan ? _end : null),
        importance: _importance,
        reminderOffsetMinutes: Value(_offset),
        updatedAt: DateTime.now(),
      );
      await repo.updateEvent(updated);
      result = updated;
    } else {
      result = await repo.create(
        title: _title.text.trim(),
        note: _note.text,
        kind: _kind.dbValue,
        date: _date,
        startMinute: _start,
        endMinute: _kind == EventKind.plan ? _end : null,
        importance: _importance,
        reminderOffsetMinutes: _offset,
      );
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    await ref.read(eventRepositoryProvider).softDelete(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  String _errorText(AppLocalizations l10n, EventFormError error) =>
      switch (error) {
        EventFormError.emptyTitle => l10n.invalidTitle,
        EventFormError.missingStart => l10n.missingStart,
        EventFormError.invalidRange => l10n.invalidTimeRange,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? l10n.edit : l10n.newEvent,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                SegmentedButton<EventKind>(
                  segments: [
                    ButtonSegment(
                        value: EventKind.reminder, label: Text(l10n.kindReminder)),
                    ButtonSegment(
                        value: EventKind.plan, label: Text(l10n.kindPlan)),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => setState(() {
                    _kind = selection.first;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('editor-title'),
                  controller: _title,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.eventTitle,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('editor-note'),
                  controller: _note,
                  decoration: InputDecoration(
                    labelText: l10n.eventNote,
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                _Row(
                  label: l10n.eventDate,
                  child: TextButton(
                    onPressed: _pickDate,
                    child: Text(DateFormat.yMMMd(
                            Localizations.localeOf(context).toString())
                        .format(_date)),
                  ),
                ),
                _Row(
                  label: l10n.eventStart,
                  child: _TimeStepper(
                    key: const ValueKey('start-stepper'),
                    text: _format(_start),
                    onDecrease: () => _stepStart(-5),
                    onIncrease: () => _stepStart(5),
                    onTapText: () => _pickTime(isStart: true),
                  ),
                ),
                if (_kind == EventKind.plan)
                  _Row(
                    label: l10n.eventEnd,
                    child: _TimeStepper(
                      key: const ValueKey('end-stepper'),
                      text: _format(_end),
                      onDecrease: () => _stepEnd(-5),
                      onIncrease: () => _stepEnd(5),
                      onTapText: () => _pickTime(isStart: false),
                    ),
                  ),
                const SizedBox(height: 4),
                _Row(
                  label: l10n.importance,
                  child: SegmentedButton<int>(
                    expandedInsets: EdgeInsets.zero,
                    segments: [
                      ButtonSegment(value: 2, label: Text(l10n.importanceHigh)),
                      ButtonSegment(
                          value: 1, label: Text(l10n.importanceMedium)),
                      ButtonSegment(value: 0, label: Text(l10n.importanceLow)),
                    ],
                    selected: {_importance},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _importance = selection.first),
                  ),
                ),
                _Row(
                  label: l10n.reminder,
                  child: DropdownButton<int?>(
                    key: const ValueKey('reminder-dropdown'),
                    value: _offset,
                    items: [
                      DropdownMenuItem<int?>(
                          value: null, child: Text(l10n.remindNone)),
                      DropdownMenuItem<int?>(
                          value: 0, child: Text(l10n.remindAtStart)),
                      for (final minutes in const [5, 10, 30])
                        DropdownMenuItem<int?>(
                          value: minutes,
                          child: Text(l10n.remindMinutesBefore(minutes)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _offset = value),
                  ),
                ),
                if (_errors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errors.map((e) => _errorText(l10n, e)).join('\n'),
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 14),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  children: [
                    if (_isEditing)
                      TextButton(
                        key: const ValueKey('editor-delete'),
                        onPressed: _delete,
                        child: Text(l10n.delete,
                            style: TextStyle(color: scheme.error)),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    FilledButton(
                      key: const ValueKey('editor-save'),
                      onPressed: _save,
                      child: Text(l10n.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
        ],
      ),
    );
  }
}

class _TimeStepper extends StatelessWidget {
  const _TimeStepper({
    super.key,
    required this.text,
    required this.onDecrease,
    required this.onIncrease,
    required this.onTapText,
  });

  final String text;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onTapText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 16),
          onPressed: onDecrease,
        ),
        TextButton(
          onPressed: onTapText,
          child: Text(
            text,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 16),
          onPressed: onIncrease,
        ),
      ],
    );
  }
}
