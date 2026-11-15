import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/formats.dart';
import '../../calendar/month_model.dart';

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
            IconButton(
              key: const ValueKey('date-calendar'),
              onPressed: _openCalendar,
              tooltip: l10n.dateLabel,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
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
    return SizedBox(
      width: width,
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
        style: AppTextStyles.secondary.copyWith(color: palette.ink),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          filled: true,
          fillColor: palette.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            borderSide: BorderSide(color: palette.lineStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            borderSide: BorderSide(color: palette.accent),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            borderSide: BorderSide(color: palette.lineStrong),
          ),
        ),
      ),
    );
  }
}

/// Compact month grid opened by [SegmentedDateField]'s calendar button.
///
/// Renders only the target month via [monthWeeks]; the selected day is filled
/// with the accent colour, today is outlined. Tapping a day pops the dialog
/// with that date.
class MiniCalendarPopover extends StatefulWidget {
  const MiniCalendarPopover({super.key, required this.value});

  final DateTime value;

  @override
  State<MiniCalendarPopover> createState() => _MiniCalendarPopoverState();
}

class _MiniCalendarPopoverState extends State<MiniCalendarPopover> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.value.year, widget.value.month, 1);
  }

  void _stepMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    if (next.year < 2000 || next.year > 2100) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final locale = Localizations.localeOf(context);
    final selected = dateOnly(widget.value);
    final today = dateOnly(DateTime.now());

    return SizedBox(
      width: 232,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _MonthButton(
                  icon: Icons.chevron_left,
                  palette: p,
                  onPressed: () => _stepMonth(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      AppFormats.monthTitle(locale, _month),
                      style: AppTextStyles.secondary.copyWith(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _MonthButton(
                  icon: Icons.chevron_right,
                  palette: p,
                  onPressed: () => _stepMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        AppFormats.weekday(locale, DateTime(2024, 1, 1 + i)),
                        style: AppTextStyles.caption.copyWith(color: p.sub),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            for (final week in monthWeeks(_month))
              Row(
                children: [
                  for (final day in week)
                    Expanded(
                      child: day == null
                          ? const SizedBox(height: 26)
                          : _MiniDay(
                              day: day,
                              isSelected: day == selected,
                              isToday: day == today,
                              palette: p,
                            ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.icon,
    required this.palette,
    required this.onPressed,
  });

  final IconData icon;
  final AppPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      icon: Icon(icon, size: 16, color: palette.sub),
    );
  }
}

class _MiniDay extends StatelessWidget {
  const _MiniDay({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.palette,
  });

  final DateTime day;
  final bool isSelected;
  final bool isToday;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(1),
      child: InkWell(
        key: ValueKey('mini-day-${day.year}-${day.month}-${day.day}'),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: () => Navigator.of(context).pop(day),
        child: Container(
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? palette.accent : null,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: isToday && !isSelected
                ? Border.all(color: palette.accent)
                : null,
          ),
          child: Text(
            '${day.day}',
            style: AppTextStyles.caption.copyWith(
              color: isSelected ? scheme.onPrimary : palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}
