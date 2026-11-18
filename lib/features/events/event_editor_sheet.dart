import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_dropdown.dart';
import '../../core/ui/app_hairline.dart';
import '../../core/ui/app_segmented.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../settings/notification_prefs.dart';
import 'event_draft.dart';
import 'fields/lead_field.dart';
import 'fields/segmented_date_field.dart';
import 'fields/segmented_time_field.dart';

/// Sheet metrics from `docs/design/10-ui-refinement.md` §9.6.
const double _sheetWidth = 480;
const double _headerHeight = 52;
const double _footerHeight = 60;
const double _fieldGap = 14;
const double _labelWidth = 80;
const double _labelGap = 12;
const double _helperGap = 6;
const double _contentPadding = 20;

/// Floating-sheet shadow: `0 24px 60px rgba(0,0,0,.18)`.
const List<BoxShadow> _sheetShadow = [
  BoxShadow(color: Color(0x2E000000), blurRadius: 60, offset: Offset(0, 24)),
];

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
  String? categoryId,
}) {
  return showDialog<Event>(
    context: context,
    builder: (context) => EventEditorDialog(
      existing: existing,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      initialKind: initialKind,
      categoryId: categoryId,
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
    this.categoryId,
  });

  final Event? existing;
  final DateTime? date;
  final int? startMinute;
  final int? endMinute;
  final EventKind? initialKind;

  /// Category preselected when creating from a category group.
  final String? categoryId;

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
    _categoryId = existing?.categoryId ?? widget.categoryId;
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
      borderRadius: BorderRadius.circular(AppRadii.button),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(color: p.subWeak),
      filled: true,
      fillColor: p.chip,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      enabledBorder: border(p.lineStrong),
      focusedBorder: border(p.accent),
      border: border(p.lineStrong),
    );
  }

  Widget _label(AppPalette p, String text) =>
      Text(text, style: AppTextStyles.body.copyWith(color: p.sub));

  Widget _fieldRow(AppPalette p, String label, Widget child, {Key? rowKey}) {
    return SizedBox(
      key: rowKey,
      height: AppSizes.field,
      child: Row(
        children: [
          SizedBox(width: _labelWidth, child: _label(p, label)),
          const SizedBox(width: _labelGap),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _fieldWithHelper(
    AppPalette p,
    String label,
    Widget field,
    String helper,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _labelWidth,
          height: AppSizes.field,
          child: Align(
            alignment: Alignment.centerLeft,
            child: _label(p, label),
          ),
        ),
        const SizedBox(width: _labelGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: _helperGap),
              Text(
                helper,
                style: AppTextStyles.secondary.copyWith(color: p.sub),
              ),
            ],
          ),
        ),
      ],
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SizedBox(
          width: _sheetWidth,
          child: Dialog(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            insetPadding: EdgeInsets.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(AppRadii.dialog),
                border: Border.all(color: p.lineStrong),
                boxShadow: _sheetShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(l10n, p),
                  AppHairline(color: p.line),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        _contentPadding,
                        16,
                        _contentPadding,
                        _contentPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSegmented<EventKind>(
                            key: const ValueKey('editor-kind'),
                            values: const [EventKind.reminder, EventKind.plan],
                            labelFor: (kind) => Text(
                              kind == EventKind.reminder
                                  ? l10n.kindReminder
                                  : l10n.kindPlan,
                            ),
                            selected: _kind,
                            onChanged: _setKind,
                          ),
                          const SizedBox(height: _fieldGap),
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.field,
                            child: TextField(
                              key: const ValueKey('editor-title'),
                              controller: _title,
                              autofocus: true,
                              textInputAction: TextInputAction.next,
                              style: AppTextStyles.body.copyWith(color: p.ink),
                              decoration: _fieldDecoration(
                                p,
                                hint: l10n.eventTitle,
                              ),
                            ),
                          ),
                          const SizedBox(height: _fieldGap),
                          _fieldRow(
                            p,
                            l10n.dateLabel,
                            SegmentedDateField(
                              key: const ValueKey('editor-date'),
                              value: _date,
                              onChanged: (date) => setState(() => _date = date),
                            ),
                            rowKey: const ValueKey('editor-date-row'),
                          ),
                          const SizedBox(height: _fieldGap),
                          if (_kind == EventKind.reminder)
                            _fieldRow(
                              p,
                              l10n.timeLabel,
                              _timeField(
                                fieldKey: const ValueKey('editor-start'),
                                stepperKey: const ValueKey('start-stepper'),
                                value: _start,
                                onChanged: _onStartChanged,
                                keyPrefix: 'start',
                              ),
                              rowKey: const ValueKey('editor-start-row'),
                            )
                          else ...[
                            _fieldRow(
                              p,
                              l10n.eventStart,
                              _timeField(
                                fieldKey: const ValueKey('editor-start'),
                                stepperKey: const ValueKey('start-stepper'),
                                value: _start,
                                onChanged: _onStartChanged,
                                keyPrefix: 'start',
                              ),
                              rowKey: const ValueKey('editor-start-row'),
                            ),
                            const SizedBox(height: _fieldGap),
                            _fieldRow(
                              p,
                              l10n.eventEnd,
                              _timeField(
                                fieldKey: const ValueKey('editor-end'),
                                stepperKey: const ValueKey('end-stepper'),
                                value: _end,
                                onChanged: (value) =>
                                    setState(() => _end = value),
                                keyPrefix: 'end',
                                allowEndOfDay: true,
                              ),
                              rowKey: const ValueKey('editor-end-row'),
                            ),
                          ],
                          const SizedBox(height: _fieldGap),
                          _fieldWithHelper(
                            p,
                            l10n.leadLabel,
                            LeadField(
                              key: const ValueKey('editor-lead'),
                              value: _lead,
                              onChanged: (value) =>
                                  setState(() => _lead = value),
                            ),
                            l10n.leadHelp,
                          ),
                          const SizedBox(height: _fieldGap),
                          _fieldWithHelper(
                            p,
                            l10n.categoryLabel,
                            _categoryDropdown(l10n, categories),
                            l10n.categoryHelp,
                          ),
                          const SizedBox(height: _fieldGap),
                          SizedBox(
                            width: double.infinity,
                            height: 72,
                            child: TextField(
                              key: const ValueKey('editor-note'),
                              controller: _note,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: AppTextStyles.body.copyWith(color: p.ink),
                              decoration: _fieldDecoration(
                                p,
                                hint: l10n.noteOptional,
                              ),
                            ),
                          ),
                          if (_errors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _errors
                                    .map((e) => _errorText(l10n, e))
                                    .join('\n'),
                                style: AppTextStyles.secondary.copyWith(
                                  color: p.danger,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _footer(l10n, p),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppLocalizations l10n, AppPalette p) {
    return SizedBox(
      height: _headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _contentPadding),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _isEditing ? l10n.editItem : l10n.newItem,
                style: AppTextStyles.headline.copyWith(color: p.ink),
              ),
            ),
            AppIconButton(
              key: const ValueKey('editor-close'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(LucideIcons.x),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(AppLocalizations l10n, AppPalette p) {
    return SizedBox(
      height: _footerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _contentPadding),
        child: Row(
          children: [
            if (_isEditing)
              TextButton(
                key: const ValueKey('editor-delete'),
                style: TextButton.styleFrom(
                  foregroundColor: p.danger,
                  minimumSize: const Size(0, AppSizes.control),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: AppTextStyles.body,
                ),
                onPressed: _delete,
                child: Text(l10n.delete),
              ),
            const Spacer(),
            AppButton.secondary(
              label: l10n.cancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            AppButton.primary(
              key: const ValueKey('editor-save'),
              label: _isEditing ? l10n.save : l10n.create,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryDropdown(AppLocalizations l10n, List<Category> categories) {
    final hasCurrent =
        _categoryId != null && categories.any((c) => c.id == _categoryId);
    return AppDropdown<String?>(
      key: const ValueKey('editor-category'),
      value: hasCurrent ? _categoryId : null,
      triggerHeight: AppSizes.field,
      semanticLabel: l10n.categoryLabel,
      items: [
        AppDropdownItem<String?>(value: null, label: l10n.uncategorized),
        for (final category in categories)
          AppDropdownItem<String?>(
            value: category.id,
            label: category.name,
            color: category.color == null ? null : Color(category.color!),
          ),
      ],
      onChanged: (value) => setState(() => _categoryId = value),
    );
  }
}
