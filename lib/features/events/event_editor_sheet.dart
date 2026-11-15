import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../calendar/category_marker.dart';
import '../settings/notification_prefs.dart';
import 'event_draft.dart';
import 'fields/lead_field.dart';
import 'fields/segmented_date_field.dart';
import 'fields/segmented_time_field.dart';

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
  int? _lead;
  String? _categoryId;
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
    if (_kind == EventKind.plan) _end ??= _defaultEnd(_start);
    _lead = existing != null
        ? existing.reminderOffsetMinutes
        : ref.read(defaultReminderOffsetProvider);
    _categoryId = existing?.categoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _defaultEnd(int? start) =>
      start == null ? null : (start + 30).clamp(0, 1440);

  void _setKind(EventKind kind) {
    setState(() {
      _kind = kind;
      if (kind == EventKind.plan &&
          (_end == null || (_start != null && _end! <= _start!))) {
        _end = _defaultEnd(_start);
      }
    });
  }

  void _onStartChanged(int? value) {
    setState(() {
      _start = value;
      if (_kind == EventKind.plan &&
          (_end == null || (_start != null && _end! <= _start!))) {
        _end = _defaultEnd(_start);
      }
    });
  }

  Future<void> _save() async {
    final end = _kind == EventKind.plan ? (_end ?? _defaultEnd(_start)) : null;
    final draft = EventDraft(
      title: _title.text,
      note: _note.text,
      kind: _kind,
      date: _date,
      startMinute: _start,
      endMinute: end,
      reminderOffsetMinutes: _lead,
      categoryId: _categoryId,
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
        endMinute: Value(end),
        reminderOffsetMinutes: Value(_lead),
        categoryId: Value(_categoryId),
        updatedAt: DateTime.now(),
      );
      await repo.updateEvent(updated);
      result = updated;
    } else {
      result = await repo.create(
        title: _title.text.trim(),
        note: _note.text,
        kind: _kind.dbValue,
        date: dateOnly(_date),
        startMinute: _start,
        endMinute: end,
        reminderOffsetMinutes: _lead,
        categoryId: _categoryId,
      );
    }
    final sync = ref.read(eventNotifierSyncProvider);
    if (existing != null) {
      sync.afterUpdate(result);
    } else {
      sync.afterCreate(result);
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final l10n = AppLocalizations.of(context);
    final p = _palette(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteForeverHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const ValueKey('confirm-delete'),
            style: TextButton.styleFrom(foregroundColor: p.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(eventRepositoryProvider).softDelete(existing.id);
    ref.read(eventNotifierSyncProvider).afterDelete(existing);
    if (mounted) Navigator.of(context).pop();
  }

  String _errorText(AppLocalizations l10n, EventFormError error) =>
      switch (error) {
        EventFormError.emptyTitle => l10n.invalidTitle,
        EventFormError.missingStart => l10n.missingStart,
        EventFormError.invalidRange => l10n.invalidTimeRange,
      };

  AppPalette _palette(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.brightness == Brightness.light
            ? AppPalette.light
            : AppPalette.dark)
        .withAccent(theme.colorScheme.primary);
  }

  InputDecoration _fieldDecoration(AppPalette p, {String? hint}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.field),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppTextStyles.secondary.copyWith(color: p.subWeak),
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      enabledBorder: border(p.lineStrong),
      focusedBorder: border(p.accent),
      border: border(p.lineStrong),
    );
  }

  Widget _row(
    AppPalette p,
    String label,
    Widget child, {
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: p.sub),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ],
      ),
    );
  }

  Widget _timeField({
    required Key fieldKey,
    required Key stepperKey,
    required int? value,
    required ValueChanged<int?> onChanged,
    required String keyPrefix,
    bool allowEndOfDay = false,
  }) {
    return KeyedSubtree(
      key: stepperKey,
      child: SegmentedTimeField(
        key: fieldKey,
        value: value,
        onChanged: onChanged,
        allowEndOfDay: allowEndOfDay,
        hourFieldKey: ValueKey('$keyPrefix-hour'),
        minuteFieldKey: ValueKey('$keyPrefix-minute'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = _palette(context);
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];

    return Dialog(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? l10n.editItem : l10n.newItem,
                  style: AppTextStyles.title.copyWith(color: p.ink),
                ),
                const SizedBox(height: 14),
                SegmentedButton<EventKind>(
                  segments: [
                    ButtonSegment(
                      value: EventKind.reminder,
                      label: Text(l10n.kindReminder),
                    ),
                    ButtonSegment(
                      value: EventKind.plan,
                      label: Text(l10n.kindPlan),
                    ),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  expandedInsets: EdgeInsets.zero,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      AppTextStyles.secondary.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onSelectionChanged: (selection) => _setKind(selection.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('editor-title'),
                  controller: _title,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  style: AppTextStyles.body.copyWith(color: p.ink),
                  decoration: _fieldDecoration(p, hint: l10n.eventTitle),
                ),
                const SizedBox(height: 6),
                _row(
                  p,
                  l10n.dateLabel,
                  SegmentedDateField(
                    key: const ValueKey('editor-date'),
                    value: _date,
                    onChanged: (date) => setState(() => _date = date),
                  ),
                ),
                if (_kind == EventKind.reminder)
                  _row(
                    p,
                    l10n.timeLabel,
                    _timeField(
                      fieldKey: const ValueKey('editor-start'),
                      stepperKey: const ValueKey('start-stepper'),
                      value: _start,
                      onChanged: _onStartChanged,
                      keyPrefix: 'start',
                    ),
                  )
                else ...[
                  _row(
                    p,
                    l10n.eventStart,
                    _timeField(
                      fieldKey: const ValueKey('editor-start'),
                      stepperKey: const ValueKey('start-stepper'),
                      value: _start,
                      onChanged: _onStartChanged,
                      keyPrefix: 'start',
                    ),
                  ),
                  _row(
                    p,
                    l10n.eventEnd,
                    _timeField(
                      fieldKey: const ValueKey('editor-end'),
                      stepperKey: const ValueKey('end-stepper'),
                      value: _end,
                      onChanged: (value) => setState(() => _end = value),
                      keyPrefix: 'end',
                      allowEndOfDay: true,
                    ),
                  ),
                ],
                _row(
                  p,
                  l10n.leadLabel,
                  LeadField(
                    key: const ValueKey('editor-lead'),
                    value: _lead,
                    onChanged: (value) => setState(() => _lead = value),
                  ),
                ),
                _row(
                  p,
                  l10n.categoryLabel,
                  _categoryDropdown(l10n, p, categories),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('editor-note'),
                  controller: _note,
                  minLines: 3,
                  maxLines: 3,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTextStyles.body.copyWith(color: p.ink),
                  decoration: _fieldDecoration(p, hint: l10n.noteOptional),
                ),
                if (_errors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errors.map((e) => _errorText(l10n, e)).join('\n'),
                      style: AppTextStyles.secondary.copyWith(color: p.danger),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_isEditing)
                      TextButton(
                        key: const ValueKey('editor-delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: p.danger,
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: AppTextStyles.secondary,
                        ),
                        onPressed: _delete,
                        child: Text(l10n.delete),
                      ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: AppTextStyles.secondary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      key: const ValueKey('editor-save'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 28),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: AppTextStyles.secondary.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                      ),
                      onPressed: _save,
                      child: Text(_isEditing ? l10n.save : l10n.create),
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

  Widget _categoryDropdown(
    AppLocalizations l10n,
    AppPalette p,
    List<Category> categories,
  ) {
    final hasCurrent =
        _categoryId != null && categories.any((c) => c.id == _categoryId);
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(AppRadii.field),
        border: Border.all(color: p.lineStrong),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: const ValueKey('editor-category'),
          value: hasCurrent ? _categoryId : null,
          isDense: true,
          isExpanded: true,
          dropdownColor: p.card,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: p.sub),
          style: AppTextStyles.secondary.copyWith(color: p.ink),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: _categoryRow(
                l10n.uncategorized,
                categoryMarkerColor(null, categories),
                p,
              ),
            ),
            for (final category in categories)
              DropdownMenuItem<String?>(
                value: category.id,
                child: _categoryRow(
                  category.name,
                  categoryMarkerColor(category.id, categories),
                  p,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _categoryId = value),
        ),
      ),
    );
  }

  Widget _categoryRow(String name, Color color, AppPalette p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.secondary.copyWith(color: p.ink),
          ),
        ),
      ],
    );
  }
}
