// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tempolet';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navSettings => 'Settings';

  @override
  String get month => 'Month';

  @override
  String get week => 'Week';

  @override
  String get day => 'Day';

  @override
  String get today => 'Today';

  @override
  String get newEvent => 'New event';

  @override
  String get newReminder => 'New reminder';

  @override
  String get newPlan => 'New plan';

  @override
  String get eventTitle => 'Title';

  @override
  String get eventNote => 'Note';

  @override
  String get eventStart => 'Starts';

  @override
  String get eventEnd => 'Ends';

  @override
  String get eventDate => 'Date';

  @override
  String get kindReminder => 'Reminder';

  @override
  String get kindPlan => 'Plan';

  @override
  String get importance => 'Importance';

  @override
  String get importanceHigh => 'High';

  @override
  String get importanceMedium => 'Medium';

  @override
  String get importanceLow => 'Low';

  @override
  String get remindAtStart => 'At start';

  @override
  String remindMinutesBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String get remindNone => 'No reminder';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get reschedule => 'Reschedule';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get overdue => 'Overdue';

  @override
  String get reminder => 'Reminder';

  @override
  String get allDone => 'All done';

  @override
  String get noEvents => 'No events';

  @override
  String get allDay => 'All day';

  @override
  String moreItems(int count) {
    return '+$count';
  }

  @override
  String hoverMoreItems(int count) {
    return 'and $count more';
  }

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get accentColor => 'Accent color';

  @override
  String get accentCustom => 'Custom';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get defaultRemindOffset => 'Default reminder lead time';

  @override
  String get notificationSound => 'Notification sound';

  @override
  String get overdueSummary => 'Overdue summary next morning';

  @override
  String get notificationsRequireAppOpen =>
      'Notifications require the app to keep running';

  @override
  String get invalidTitle => 'Please enter a title';

  @override
  String get invalidTimeRange => 'End time must be after start time';

  @override
  String get missingStart => 'Please choose a start time';
}
