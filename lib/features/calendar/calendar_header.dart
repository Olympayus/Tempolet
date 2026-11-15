import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../events/event_editor_sheet.dart';
import 'calendar_state.dart';

/// The single header row shared by the month, week and day views.
///
/// It owns every global calendar control (title, view switch, today, paging,
/// new item and the sidebar toggle) so those controls never disappear when
/// the body switches views.
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    key: const ValueKey('calendar-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title,
                  ),
                ),
                const SizedBox(width: 24),
                SegmentedButton<CalendarViewMode>(
                  segments: [
                    ButtonSegment(
                      value: CalendarViewMode.month,
                      label: Text(l10n.month),
                    ),
                    ButtonSegment(
                      value: CalendarViewMode.week,
                      label: Text(l10n.week),
                    ),
                    ButtonSegment(
                      value: CalendarViewMode.day,
                      label: Text(l10n.day),
                    ),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => ref
                      .read(calendarViewModeProvider.notifier)
                      .set(selection.first),
                  style: ButtonStyle(
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -3.5,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 12),
                    ),
                    textStyle: const WidgetStatePropertyAll(
                      AppTextStyles.secondary,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? palette.ink
                          : palette.sub,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? palette.card
                          : Colors.transparent,
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: palette.lineStrong),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.segment),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => ref
                .read(selectedDayProvider.notifier)
                .select(dateOnly(DateTime.now())),
            style: TextButton.styleFrom(
              foregroundColor: palette.ink,
              textStyle: AppTextStyles.body,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.today),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey('calendar-prev'),
            onPressed: () => shift(-1),
            icon: const Icon(LucideIcons.chevronLeft, size: 18),
            color: palette.sub,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
          IconButton(
            key: const ValueKey('calendar-next'),
            onPressed: () => shift(1),
            icon: const Icon(LucideIcons.chevronRight, size: 18),
            color: palette.sub,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey('calendar-new'),
            onPressed: () => showEventEditor(context, date: selected),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: Text(l10n.newItem),
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: Colors.white,
              textStyle: AppTextStyles.body,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
          ),
          if (mode != CalendarViewMode.day) ...[
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey('calendar-sidebar-toggle'),
              tooltip: l10n.toggleSidebar,
              // The page owns the width-aware effective state; the header
              // only flips the user's explicit choice.
              onPressed: onToggleSidebar,
              icon: const Icon(LucideIcons.panelRight, size: 18),
              color: palette.sub,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            ),
          ],
        ],
      ),
    );
  }
}
