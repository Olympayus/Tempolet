import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/app_segmented.dart';
import '../../core/ui/touch_target.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../events/event_editor_sheet.dart';
import 'calendar_state.dart';

/// The single header row shared by the month, week and day views.
///
/// It owns every global calendar control (title, view switch, today, paging,
/// new item and the sidebar toggle) so those controls never disappear when
/// the body switches views. 64 high with a bottom hairline
/// (`docs/design/10-ui-refinement.md` §9.3).
class CalendarHeader extends ConsumerWidget {
  const CalendarHeader({super.key, this.onToggleSidebar});

  /// Flips the user's explicit sidebar choice to the opposite of the
  /// width-aware effective state owned by the page.
  final VoidCallback? onToggleSidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final mode = ref.watch(calendarViewModeProvider);
    final selected = ref.watch(selectedDayProvider);

    final title = switch (mode) {
      CalendarViewMode.month => AppFormats.monthTitle(locale, selected),
      CalendarViewMode.week => AppFormats.weekRange(
        locale,
        startOfWeek(selected),
      ),
      CalendarViewMode.day => AppFormats.dayTitle(locale, selected),
    };
    // Only the day view's date title names the festival
    // (`docs/design/03-calendar.md` D36).
    final holidays = ref.watch(holidaysProvider).value ?? const <Holiday>[];
    final holiday = mode == CalendarViewMode.day
        ? _holidayOn(holidays, selected)
        : null;

    void shift(int delta) {
      final days = ref.read(selectedDayProvider.notifier);
      switch (mode) {
        case CalendarViewMode.month:
          days.shiftMonths(delta);
        case CalendarViewMode.week:
          days.shiftDays(7 * delta);
        case CalendarViewMode.day:
          days.shiftDays(delta);
      }
    }

    final viewSwitch = AppSegmented<CalendarViewMode>(
      key: const ValueKey('calendar-view-segmented'),
      values: const [
        CalendarViewMode.month,
        CalendarViewMode.week,
        CalendarViewMode.day,
      ],
      labelFor: (value) => Text(switch (value) {
        CalendarViewMode.month => l10n.month,
        CalendarViewMode.week => l10n.week,
        CalendarViewMode.day => l10n.day,
      }),
      selected: mode,
      onChanged: (value) =>
          ref.read(calendarViewModeProvider.notifier).set(value),
    );
    // Touch layouts reserve a 44-high hit band around the 28–36px track
    // (`design spec` §8.7); desktop keeps the compact 28px footprint.
    final viewSwitchTarget = isTouchLayout(resolveAppLayout(context))
        ? TouchTarget(
            key: const ValueKey('calendar-view-segmented-hit'),
            child: viewSwitch,
          )
        : viewSwitch;

    return Container(
      key: const ValueKey('calendar-header'),
      height: AppSizes.header,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          // The title gives way first: it sits in the only flexible slot, so
          // the controls to its right keep their size and order.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      text: title,
                      children: [
                        if (holiday != null)
                          TextSpan(
                            text: ' · ${holiday.name}',
                            style: AppTextStyles.title.copyWith(
                              color: palette.festival,
                            ),
                          ),
                      ],
                    ),
                    key: const ValueKey('calendar-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AppIconButton(
                  key: const ValueKey('calendar-prev'),
                  onPressed: () => shift(-1),
                  icon: const AppIcon.chevronLeft(),
                ),
                AppIconButton(
                  key: const ValueKey('calendar-next'),
                  onPressed: () => shift(1),
                  icon: const AppIcon.chevronRight(),
                ),
                const SizedBox(width: 8),
                AppButton.secondary(
                  label: l10n.today,
                  onPressed: () => ref
                      .read(selectedDayProvider.notifier)
                      .select(dateOnly(ref.read(todayProvider))),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          viewSwitchTarget,
          const SizedBox(width: 8),
          AppButton.primary(
            key: const ValueKey('calendar-new'),
            label: l10n.newItem,
            leadingIcon: const AppIcon.plus(size: 16, color: Colors.white),
            onPressed: () => showEventEditor(context, date: selected),
          ),
          if (mode != CalendarViewMode.day) ...[
            const SizedBox(width: 8),
            AppIconButton(
              key: const ValueKey('calendar-sidebar-toggle'),
              tooltip: l10n.toggleSidebar,
              // The page owns the width-aware effective state; the header
              // only flips the user's explicit choice.
              onPressed: onToggleSidebar,
              icon: const Icon(LucideIcons.panelRight),
            ),
          ],
        ],
      ),
    );
  }
}

Holiday? _holidayOn(List<Holiday> holidays, DateTime day) {
  final target = dateOnly(day);
  for (final holiday in holidays) {
    if (dateOnly(holiday.date) == target) return holiday;
  }
  return null;
}
