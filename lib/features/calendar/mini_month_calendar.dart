import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import 'month_model.dart';

/// Reusable compact month grid (`docs/design/04-reminders.md` §2.1,
/// `10-ui-refinement.md` §9.15).
///
/// Today is always a solid accent circle with white text; the selected day is
/// an `accentTint` fill with `ink` text and no stroke. A day with events shows
/// a 2px dot, a day with a plan a 4px bar, in the supplied category colour.
/// The wheel flips months and the header year-month opens a month picker.
class MiniMonthCalendar extends StatefulWidget {
  const MiniMonthCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    this.eventDays = const {},
    this.eventDayColors = const {},
    this.planDays = const {},
    this.onSelect,
    this.onMonthChanged,
    this.width = 180,
  });

  /// Month to display (any date inside it); normally the first of the month.
  final DateTime month;

  /// Selected day, rendered with `accentTint` unless it is today.
  final DateTime selected;

  /// Wall-clock today, rendered as a solid accent circle.
  final DateTime today;

  /// Days that carry an event; each gets a marker under its number.
  final Set<DateTime> eventDays;

  /// Optional category colour per marked day. Days without an entry use the
  /// accent colour.
  final Map<DateTime, Color> eventDayColors;

  /// Marked days that contain a plan; they draw a 4px bar instead of a dot.
  final Set<DateTime> planDays;

  final ValueChanged<DateTime>? onSelect;
  final ValueChanged<DateTime>? onMonthChanged;
  final double width;

  @override
  State<MiniMonthCalendar> createState() => _MiniMonthCalendarState();
}

class _MiniMonthCalendarState extends State<MiniMonthCalendar> {
  static const double _rowHeight = 26;
  static const double _daySize = 22;

  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = firstDayOfMonth(widget.month);
  }

  @override
  void didUpdateWidget(MiniMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = firstDayOfMonth(widget.month);
    if (next != _month) _month = next;
  }

  void _stepMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta, 1);
    if (next.year < 2000 || next.year > 2100) return;
    _setMonth(next);
  }

  void _setMonth(DateTime next) {
    final normalized = firstDayOfMonth(next);
    if (normalized == _month) return;
    setState(() => _month = normalized);
    widget.onMonthChanged?.call(normalized);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    // Claim the wheel so a parent scroll view does not also scroll.
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final delta = (event as PointerScrollEvent).scrollDelta.dy > 0 ? 1 : -1;
      _stepMonth(delta);
    });
  }

  Future<void> _openMonthPicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthPickerDialog(month: _month),
    );
    if (picked == null || !mounted) return;
    _setMonth(picked);
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
    final theme = Theme.of(context);
    final palette = _palette(context);
    final locale = Localizations.localeOf(context);
    final selected = dateOnly(widget.selected);
    final today = dateOnly(widget.today);
    final eventDays = {for (final day in widget.eventDays) dateOnly(day)};
    final planDays = {for (final day in widget.planDays) dateOnly(day)};
    final colors = {
      for (final entry in widget.eventDayColors.entries)
        dateOnly(entry.key): entry.value,
    };
    final weeks = monthWeeks(_month);

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: SizedBox(
        width: widget.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 24,
                child: Row(
                  children: [
                    _NavButton(
                      buttonKey: const ValueKey('mini-month-prev'),
                      icon: Icons.chevron_left,
                      palette: palette,
                      onPressed: () => _stepMonth(-1),
                    ),
                    Expanded(
                      child: InkWell(
                        key: const ValueKey('mini-month-title'),
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                        onTap: _openMonthPicker,
                        child: Center(
                          child: Text(
                            AppFormats.monthTitle(locale, _month),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.secondary.copyWith(
                              color: palette.ink,
                              fontWeight: FontWeight.w600,
                              fontVariations: const [
                                FontVariation('wght', 600),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _NavButton(
                      buttonKey: const ValueKey('mini-month-next'),
                      icon: Icons.chevron_right,
                      palette: palette,
                      onPressed: () => _stepMonth(1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 18,
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              AppFormats.weekday(
                                locale,
                                DateTime(2024, 1, 1 + i),
                              ),
                              maxLines: 1,
                              style: AppTextStyles.caption.copyWith(
                                color: palette.sub,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              for (final week in weeks)
                SizedBox(
                  height: _rowHeight,
                  child: Row(
                    children: [
                      for (final day in week)
                        Expanded(
                          child: day == null
                              ? const SizedBox()
                              : _dayCell(
                                  day: day,
                                  selected: selected,
                                  today: today,
                                  eventDays: eventDays,
                                  planDays: planDays,
                                  colors: colors,
                                  palette: palette,
                                  onPrimary: theme.colorScheme.onPrimary,
                                ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayCell({
    required DateTime day,
    required DateTime selected,
    required DateTime today,
    required Set<DateTime> eventDays,
    required Set<DateTime> planDays,
    required Map<DateTime, Color> colors,
    required AppPalette palette,
    required Color onPrimary,
  }) {
    final isToday = day == today;
    final isSelected = day == selected;
    final hasMarker = eventDays.contains(day);
    final isPlan = planDays.contains(day);
    final background = isToday
        ? palette.accent
        : isSelected
        ? palette.accentTint
        : null;
    final foreground = isToday ? onPrimary : palette.ink;
    final keySuffix =
        '${day.year}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';

    return Center(
      child: InkWell(
        key: ValueKey('mini-day-$keySuffix'),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: widget.onSelect == null ? null : () => widget.onSelect!(day),
        child: Container(
          key: ValueKey('mini-day-bg-$keySuffix'),
          width: _daySize,
          height: _daySize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: isToday ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isToday ? null : BorderRadius.circular(AppRadii.chip),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: hasMarker ? 3 : 0),
                child: Text(
                  '${day.day}',
                  maxLines: 1,
                  style: AppTextStyles.caption.copyWith(color: foreground),
                ),
              ),
              if (hasMarker)
                Positioned(
                  bottom: 1,
                  child: Container(
                    key: ValueKey('mini-marker-$keySuffix'),
                    width: isPlan ? 4 : 2,
                    height: 2,
                    decoration: BoxDecoration(
                      color: colors[day] ?? palette.accent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.buttonKey,
    required this.icon,
    required this.palette,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final AppPalette palette;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 20, height: 20),
      iconSize: 14,
      icon: Icon(icon, size: 14, color: palette.sub),
    );
  }
}

/// Year + 12-month grid opened by tapping the mini calendar's header.
class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.month});

  final DateTime month;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.month.year;

  AppPalette _palette(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.brightness == Brightness.light
            ? AppPalette.light
            : AppPalette.dark)
        .withAccent(theme.colorScheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette(context);
    final locale = Localizations.localeOf(context);

    return Dialog(
      key: const ValueKey('mini-month-picker'),
      backgroundColor: palette.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
      child: SizedBox(
        width: 232,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    _NavButton(
                      buttonKey: const ValueKey('mini-picker-year-prev'),
                      icon: Icons.chevron_left,
                      palette: palette,
                      onPressed: () {
                        if (_year > 2000) setState(() => _year--);
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_year',
                          style: AppTextStyles.secondary.copyWith(
                            color: palette.ink,
                            fontWeight: FontWeight.w600,
                            fontVariations: const [FontVariation('wght', 600)],
                          ),
                        ),
                      ),
                    ),
                    _NavButton(
                      buttonKey: const ValueKey('mini-picker-year-next'),
                      icon: Icons.chevron_right,
                      palette: palette,
                      onPressed: () {
                        if (_year < 2100) setState(() => _year++);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              for (var row = 0; row < 3; row++)
                Row(
                  children: [
                    for (var column = 0; column < 4; column++)
                      Expanded(
                        child: _monthCell(
                          month: row * 4 + column + 1,
                          locale: locale,
                          palette: palette,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthCell({
    required int month,
    required Locale locale,
    required AppPalette palette,
  }) {
    final selected = _year == widget.month.year && month == widget.month.month;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        key: ValueKey('mini-picker-month-$month'),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: () => Navigator.of(context).pop(DateTime(_year, month, 1)),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? palette.accentTint : null,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Text(
            AppFormats.monthName(locale, DateTime(_year, month, 1)),
            maxLines: 1,
            style: AppTextStyles.secondary.copyWith(color: palette.ink),
          ),
        ),
      ),
    );
  }
}
