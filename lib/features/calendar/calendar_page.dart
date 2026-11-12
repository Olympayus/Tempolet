import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import 'calendar_state.dart';
import 'month_view.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(calendarViewModeProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      key: const ValueKey('calendar-page'),
      body: switch (mode) {
        CalendarViewMode.month => const MonthView(),
        // Replaced by the real views in Tasks 10 and 11.
        CalendarViewMode.week => Center(child: Text(l10n.week)),
        CalendarViewMode.day => Center(child: Text(l10n.day)),
      },
    );
  }
}
