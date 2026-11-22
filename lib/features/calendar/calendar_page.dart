import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout.dart';
import 'calendar_header.dart';
import 'calendar_state.dart';
import 'day_view.dart';
import 'month_view.dart';
import 'phone_calendar.dart';
import 'sidebar.dart';
import 'week_view.dart';

/// Cross-fade length between calendar views (`docs/design/08-motion.md`).
const kCalendarViewFadeDuration = Duration(milliseconds: 120);

/// Below this window width the sidebar defaults to collapsed
/// (`docs/design/02-shell-desktop.md` §6).
const kSidebarBreakpoint = 1180;

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phone shell: its own month/week structure (`02-shell-mobile.md` §2).
    if (resolveAppLayout(context) == AppLayout.phone) {
      return const Scaffold(
        key: ValueKey('calendar-page'),
        body: PhoneCalendarPage(),
      );
    }

    final mode = ref.watch(calendarViewModeProvider);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final body = switch (mode) {
      CalendarViewMode.month => const MonthView(),
      CalendarViewMode.week => const WeekView(),
      CalendarViewMode.day => const DayView(),
    };

    return Scaffold(
      key: const ValueKey('calendar-page'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // An explicit choice always wins; the table defaults to collapsed
          // in portrait or on narrower windows until the user first toggles.
          final preference = ref.watch(sidebarPreferenceProvider);
          final portrait =
              MediaQuery.orientationOf(context) == Orientation.portrait;
          final sidebarOpen =
              preference ??
              (!portrait && constraints.maxWidth >= kSidebarBreakpoint);
          // Day view owns its own 216px stats rail and hides the toggle
          // (`docs/design/02-shell-desktop.md` §4, decision D38).
          final showSidebar = sidebarOpen && mode != CalendarViewMode.day;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  children: [
                    // The header stays outside the switcher: it must not
                    // cross-fade.
                    CalendarHeader(
                      onToggleSidebar: () => ref
                          .read(sidebarPreferenceProvider.notifier)
                          .set(!sidebarOpen),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : kCalendarViewFadeDuration,
                        child: KeyedSubtree(key: ValueKey(mode), child: body),
                      ),
                    ),
                  ],
                ),
              ),
              if (showSidebar)
                const CalendarSidebar(key: ValueKey('calendar-sidebar')),
            ],
          );
        },
      ),
    );
  }
}
