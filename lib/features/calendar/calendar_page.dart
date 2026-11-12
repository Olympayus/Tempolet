import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';

/// Placeholder — replaced by the real calendar in later tasks.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('calendar-page'),
      body: Center(child: Text(AppLocalizations.of(context).navCalendar)),
    );
  }
}
