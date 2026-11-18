import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/utils/dates.dart';
import '../../calendar/calendar_state.dart';
import '../../calendar/mini_month_calendar.dart';
import '../../calendar/month_model.dart';

/// Segmented-field metrics from `docs/design/10-ui-refinement.md` §9.6.
const double _segmentHeight = 28;

/// Year / month / day segmented input with a mini-calendar popover.
///
/// Each segment is a compact numeric field; Tab moves to the next segment and
/// values are clamped to a real date (year 2000–2100, month 1–12, day ends at
/// the month end).
class SegmentedDateField extends StatefulWidget {
  const SegmentedDateField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  State<SegmentedDateField> createState() => _SegmentedDateFieldState();
}

class _SegmentedDateFieldState extends State<SegmentedDateField> {
  late final TextEditingController _year;
  late final TextEditingController _month;
  late final TextEditingController _day;
  late final FocusNode _yearFocus;
  late final FocusNode _monthFocus;
  late final FocusNode _dayFocus;
  late DateTime _value;

  @override
  void initState() {
    super.initState();
    _value = dateOnly(widget.value);
    _year = TextEditingController(text: '${_value.year}');
    _month = TextEditingController(text: '${_value.month}');
    _day = TextEditingController(text: '${_value.day}');
    _yearFocus = FocusNode()..addListener(_normalizeOnBlur);
    _monthFocus = FocusNode()..addListener(_normalizeOnBlur);
    _dayFocus = FocusNode()..addListener(_normalizeOnBlur);
  }

  @override
  void didUpdateWidget(SegmentedDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = dateOnly(widget.value);
    if (next == _value) return;
    _value = next;
    _syncControllers();
  }

  @override
  void dispose() {
    _year.dispose();
    _month.dispose();
    _day.dispose();
    _yearFocus.dispose();
    _monthFocus.dispose();
    _dayFocus.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _setText(_year, '${_value.year}', focused: _yearFocus.hasFocus);
    _setText(_month, '${_value.month}', focused: _monthFocus.hasFocus);
    _setText(_day, '${_value.day}', focused: _dayFocus.hasFocus);
  }

  void _setText(
    TextEditingController controller,
    String text, {
    required bool focused,
  }) {
    if (focused || controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _normalizeOnBlur() {
    if (_yearFocus.hasFocus || _monthFocus.hasFocus || _dayFocus.hasFocus) {
      return;
    }
    _syncControllers();
  }

  void _onSegmentChanged() {
    final yearText = _year.text;
    final monthText = _month.text;
    final dayText = _day.text;
    final year = yearText.length == 4 ? int.tryParse(yearText) : null;
    final month = monthText.isEmpty ? null : int.tryParse(monthText);
    final day = dayText.isEmpty ? null : int.tryParse(dayText);

    // Let the user finish typing a four-digit year or a non-empty segment.
    if (year == null && _yearFocus.hasFocus) return;
    if (month == null && _monthFocus.hasFocus) return;
    if (day == null && _dayFocus.hasFocus) return;

    final next = clampDayOfMonth(
      (year ?? _value.year).clamp(2000, 2100),
      (month ?? _value.month).clamp(1, 12),
      (day ?? _value.day).clamp(1, 31),
    );
    if (next != _value) {
      _value = next;
      widget.onChanged(next);
    }
    if (!_dayFocus.hasFocus) _setText(_day, '${next.day}', focused: false);
  }

  Future<void> _openCalendar() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _palette(context).card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
        child: MiniCalendarPopover(value: _value),
      ),
    );
    if (picked == null) return;
    if (!mounted) return;
    final next = dateOnly(picked);
    if (next == _value) return;
    _value = next;
    _syncControllers();
    widget.onChanged(next);
  }

  AppPalette _palette(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.brightness == Brightness.light
            ? AppPalette.light
            : AppPalette.dark)
        .withAccent(theme.colorScheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette(context);
    final l10n = AppLocalizations.of(context);
    final units = [l10n.yearUnit, l10n.monthUnit, l10n.dayUnit];
    final unitStyle = AppTextStyles.caption.copyWith(color: p.sub);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
      },
      child: FocusTraversalGroup(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              fieldKey: const ValueKey('date-year'),
              controller: _year,
              focusNode: _yearFocus,
              width: 44,
              maxLength: 4,
              palette: p,
              onChanged: _onSegmentChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(units[0], style: unitStyle),
            ),
            _Segment(
              fieldKey: const ValueKey('date-month'),
              controller: _month,
              focusNode: _monthFocus,
              width: 36,
              maxLength: 2,
              palette: p,
              onChanged: _onSegmentChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(units[1], style: unitStyle),
            ),
            _Segment(
              fieldKey: const ValueKey('date-day'),
              controller: _day,
              focusNode: _dayFocus,
              width: 36,
              maxLength: 2,
              palette: p,
              onChanged: _onSegmentChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(units[2], style: unitStyle),
            ),
            const SizedBox(width: 6),
            AppIconButton(
              key: const ValueKey('date-calendar'),
              onPressed: _openCalendar,
              tooltip: l10n.dateLabel,
              icon: Icon(Icons.calendar_today_outlined, size: 15, color: p.sub),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.width,
    required this.maxLength,
    required this.palette,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final double width;
  final int maxLength;
  final AppPalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return SizedBox(
          width: width,
          height: _segmentHeight,
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: maxLength,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(maxLength),
            ],
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            style: AppTextStyles.body.copyWith(color: palette.ink),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              filled: true,
              fillColor: focused ? kSelectedSegmentFill : palette.chip,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: palette.lineStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: palette.accent),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: palette.lineStrong),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact month grid opened by [SegmentedDateField]'s calendar button.
///
/// Delegates the grid to the shared [MiniMonthCalendar] (`10-ui-refinement.md`
/// §9.15) and pops the dialog with the picked day.
class MiniCalendarPopover extends ConsumerStatefulWidget {
  const MiniCalendarPopover({super.key, required this.value});

  final DateTime value;

  @override
  ConsumerState<MiniCalendarPopover> createState() =>
      _MiniCalendarPopoverState();
}

class _MiniCalendarPopoverState extends ConsumerState<MiniCalendarPopover> {
  late DateTime _month = DateTime(widget.value.year, widget.value.month, 1);

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(ref.watch(todayProvider));

    return SizedBox(
      width: 232,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: MiniMonthCalendar(
          month: _month,
          selected: widget.value,
          today: today,
          width: 212,
          onSelect: (day) => Navigator.of(context).pop(day),
          onMonthChanged: (month) =>
              setState(() => _month = DateTime(month.year, month.month, 1)),
        ),
      ),
    );
  }
}
