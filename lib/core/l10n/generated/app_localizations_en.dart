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

  @override
  String get notifToday => 'Today';

  @override
  String get notifStartingNow => 'Starting now';

  @override
  String notifStartsIn(int minutes) {
    return 'Starts in $minutes min';
  }

  @override
  String get notifOverdueTitle => 'Unfinished items';

  @override
  String notifOverdueBody(int count) {
    return 'Yesterday left $count items undone';
  }

  @override
  String get settingsDesktop => 'Desktop';

  @override
  String get closeToTray => 'Minimise to tray when closing';

  @override
  String get launchAtStartup => 'Launch at startup';

  @override
  String get newItem => 'New';

  @override
  String get editItem => 'Edit';

  @override
  String get create => 'Create';

  @override
  String get dateLabel => 'Date';

  @override
  String get timeLabel => 'Time';

  @override
  String get leadLabel => 'Remind';

  @override
  String get categoryLabel => 'Category';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get custom => 'Custom…';

  @override
  String get leadUnitDay => 'd';

  @override
  String get leadUnitHour => 'h';

  @override
  String get leadUnitMinute => 'm before';

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String get viewCompleted => 'View completed ›';

  @override
  String get addReminderOrPlan => '＋ Add reminder or plan';

  @override
  String get completedTitle => 'Completed';

  @override
  String get clear => 'Clear';

  @override
  String get restore => 'Restore';

  @override
  String get todayGroup => 'Today';

  @override
  String get yesterdayGroup => 'Yesterday';

  @override
  String get earlierGroup => 'Earlier';

  @override
  String get deleteForeverHint => 'This cannot be undone';

  @override
  String get holidayBadge => 'Off';

  @override
  String get workdayBadge => 'Work';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get dataLocation => 'Data folder';

  @override
  String get openFolder => 'Open folder ›';

  @override
  String get restoreDefault => 'Restore default';

  @override
  String get customColor => 'Custom color';

  @override
  String get tomorrowPreview => 'Tomorrow';

  @override
  String plansCount(int count) {
    return '$count plans';
  }

  @override
  String remindersCount(int count) {
    return '$count reminders';
  }

  @override
  String get noSchedule => 'Nothing scheduled';

  @override
  String get toggleSidebar => 'Sidebar';
}
