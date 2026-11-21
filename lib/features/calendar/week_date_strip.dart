import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import 'calendar_state.dart';

/// Seven-day strip used above the phone week timeline and as the tablet
/// week's narrow fallback (content width < 900, `v0.1.5 design` §8.4):
/// horizontal swipes move ±7 days, tapping a day selects it.
class WeekDateStrip extends ConsumerWidget {
  const WeekDateStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final locale = Localizations.localeOf(context);
    final selected = ref.watch(selectedDayProvider);
    final today = dateOnly(ref.watch(todayProvider));
    final start = DateTime(selected.year, selected.month, selected.day - 3);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];

    Widget cell(DateTime day) {
      final isToday = day == today;
      final isSelected = day == selected;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(selectedDayProvider.notifier).select(day),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppFormats.weekday(locale, day),
                style: AppTextStyles.caption.copyWith(color: palette.sub),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? palette.accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: !isSelected && isToday
                      ? Border.all(color: palette.accent, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : palette.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -150) {
          ref.read(selectedDayProvider.notifier).shiftDays(7);
        } else if (velocity > 150) {
          ref.read(selectedDayProvider.notifier).shiftDays(-7);
        }
      },
      child: Container(
        key: const ValueKey('week-date-strip'),
        height: 64,
        decoration: BoxDecoration(
          color: palette.side,
          border: Border(bottom: BorderSide(color: palette.line)),
        ),
        child: Row(children: [for (final day in days) cell(day)]),
      ),
    );
  }
}
