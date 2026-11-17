import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../data/database/database.dart';

/// The 10px 「休」/「班」 pill shown next to a holiday date
/// (`docs/design/03-calendar.md` §1.1). A day off uses the festival tint and
/// text; a 调休 workday uses the neutral chip fill and secondary text.
class HolidayBadge extends StatelessWidget {
  const HolidayBadge({
    super.key,
    required this.holiday,
    required this.palette,
    this.fontSize = 10,
  });

  final Holiday holiday;
  final AppPalette palette;

  /// The month cell uses the denser 9px pill; the week header keeps 10px.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workday = holiday.isWorkday;

    return Container(
      key: ValueKey('holiday-badge-${_dateKey(holiday.date)}'),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
      decoration: BoxDecoration(
        color: workday ? palette.chip : palette.festivalTint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        workday ? l10n.workdayBadge : l10n.holidayBadge,
        maxLines: 1,
        style: AppTextStyles.caption.copyWith(
          fontSize: fontSize,
          color: workday ? palette.sub : palette.festival,
        ),
      ),
    );
  }
}

String _dateKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
