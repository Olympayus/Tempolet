import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Tempolet'**
  String get appTitle;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get newEvent;

  /// No description provided for @newReminder.
  ///
  /// In en, this message translates to:
  /// **'New reminder'**
  String get newReminder;

  /// No description provided for @newPlan.
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get newPlan;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get eventTitle;

  /// No description provided for @eventNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get eventNote;

  /// No description provided for @eventStart.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get eventStart;

  /// No description provided for @eventEnd.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get eventEnd;

  /// No description provided for @eventDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get eventDate;

  /// No description provided for @kindReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get kindReminder;

  /// No description provided for @kindPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get kindPlan;

  /// No description provided for @importance.
  ///
  /// In en, this message translates to:
  /// **'Importance'**
  String get importance;

  /// No description provided for @importanceHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get importanceHigh;

  /// No description provided for @importanceMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get importanceMedium;

  /// No description provided for @importanceLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get importanceLow;

  /// No description provided for @remindAtStart.
  ///
  /// In en, this message translates to:
  /// **'At start'**
  String get remindAtStart;

  /// No description provided for @remindMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String remindMinutesBefore(int minutes);

  /// No description provided for @remindNone.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get remindNone;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get reschedule;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get allDone;

  /// No description provided for @noEvents.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get noEvents;

  /// No description provided for @allDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get allDay;

  /// No description provided for @moreItems.
  ///
  /// In en, this message translates to:
  /// **'+{count}'**
  String moreItems(int count);

  /// No description provided for @hoverMoreItems.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String hoverMoreItems(int count);

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeMode;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get accentColor;

  /// No description provided for @accentCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get accentCustom;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @defaultRemindOffset.
  ///
  /// In en, this message translates to:
  /// **'Default reminder lead time'**
  String get defaultRemindOffset;

  /// No description provided for @notificationSound.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get notificationSound;

  /// No description provided for @overdueSummary.
  ///
  /// In en, this message translates to:
  /// **'Overdue summary next morning'**
  String get overdueSummary;

  /// No description provided for @notificationsRequireAppOpen.
  ///
  /// In en, this message translates to:
  /// **'Notifications require the app to keep running'**
  String get notificationsRequireAppOpen;

  /// No description provided for @notificationsWindowsNote.
  ///
  /// In en, this message translates to:
  /// **'Windows doesn\'t ask for notification permission; if reminders don\'t appear, allow notifications in system settings'**
  String get notificationsWindowsNote;

  /// No description provided for @accentHint.
  ///
  /// In en, this message translates to:
  /// **'Used for today, selections and primary buttons'**
  String get accentHint;

  /// No description provided for @defaultRemindHint.
  ///
  /// In en, this message translates to:
  /// **'Lead time used when creating a new reminder'**
  String get defaultRemindHint;

  /// No description provided for @overdueSummaryHint.
  ///
  /// In en, this message translates to:
  /// **'Summarises unfinished items every morning'**
  String get overdueSummaryHint;

  /// No description provided for @closeToTrayHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps running in the tray after the window closes'**
  String get closeToTrayHint;

  /// No description provided for @launchAtStartupHint.
  ///
  /// In en, this message translates to:
  /// **'Starts automatically after you sign in to Windows'**
  String get launchAtStartupHint;

  /// No description provided for @invalidTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get invalidTitle;

  /// No description provided for @invalidTimeRange.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time'**
  String get invalidTimeRange;

  /// No description provided for @missingStart.
  ///
  /// In en, this message translates to:
  /// **'Please choose a start time'**
  String get missingStart;

  /// No description provided for @notifToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notifToday;

  /// No description provided for @notifStartingNow.
  ///
  /// In en, this message translates to:
  /// **'Starting now'**
  String get notifStartingNow;

  /// No description provided for @notifStartsIn.
  ///
  /// In en, this message translates to:
  /// **'Starts in {minutes} min'**
  String notifStartsIn(int minutes);

  /// No description provided for @notifOverdueTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfinished items'**
  String get notifOverdueTitle;

  /// No description provided for @notifOverdueBody.
  ///
  /// In en, this message translates to:
  /// **'Yesterday left {count} items undone'**
  String notifOverdueBody(int count);

  /// No description provided for @settingsDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get settingsDesktop;

  /// No description provided for @closeToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimise to tray when closing'**
  String get closeToTray;

  /// No description provided for @launchAtStartup.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup'**
  String get launchAtStartup;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newItem;

  /// No description provided for @editItem.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editItem;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @yearUnit.
  ///
  /// In en, this message translates to:
  /// **'y'**
  String get yearUnit;

  /// No description provided for @monthUnit.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get monthUnit;

  /// No description provided for @dayUnit.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get dayUnit;

  /// No description provided for @timeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// No description provided for @leadLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind'**
  String get leadLabel;

  /// No description provided for @leadHelp.
  ///
  /// In en, this message translates to:
  /// **'How early to send a reminder'**
  String get leadHelp;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @categoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Used for labels and filtering'**
  String get categoryHelp;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom…'**
  String get custom;

  /// No description provided for @leadUnitDay.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get leadUnitDay;

  /// No description provided for @leadUnitHour.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get leadUnitHour;

  /// No description provided for @leadUnitMinute.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get leadUnitMinute;

  /// No description provided for @leadBeforeSuffix.
  ///
  /// In en, this message translates to:
  /// **' before'**
  String get leadBeforeSuffix;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// No description provided for @viewCompleted.
  ///
  /// In en, this message translates to:
  /// **'View completed ›'**
  String get viewCompleted;

  /// No description provided for @addReminderOrPlan.
  ///
  /// In en, this message translates to:
  /// **'＋ Add reminder or plan'**
  String get addReminderOrPlan;

  /// No description provided for @editInSidebar.
  ///
  /// In en, this message translates to:
  /// **'Edit in sidebar ›'**
  String get editInSidebar;

  /// No description provided for @completedTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedTitle;

  /// No description provided for @completedAt.
  ///
  /// In en, this message translates to:
  /// **'completed {date} · {time}'**
  String completedAt(String date, String time);

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 selected} other{{count} selected}}'**
  String selectedCount(int count);

  /// No description provided for @completedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing completed yet'**
  String get completedEmptyTitle;

  /// No description provided for @completedEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Completed reminders and plans show up here.'**
  String get completedEmptyHint;

  /// No description provided for @todayGroup.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todayGroup;

  /// No description provided for @yesterdayGroup.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterdayGroup;

  /// No description provided for @earlierGroup.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlierGroup;

  /// No description provided for @deleteForeverHint.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone'**
  String get deleteForeverHint;

  /// No description provided for @holidayBadge.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get holidayBadge;

  /// No description provided for @workdayBadge.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get workdayBadge;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @dataLocation.
  ///
  /// In en, this message translates to:
  /// **'Data folder'**
  String get dataLocation;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder ›'**
  String get openFolder;

  /// No description provided for @restoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore default'**
  String get restoreDefault;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get customColor;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get confirm;

  /// No description provided for @tomorrowPreview.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrowPreview;

  /// No description provided for @plansCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 plan} other{{count} plans}}'**
  String plansCount(int count);

  /// No description provided for @remindersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 reminder} other{{count} reminders}}'**
  String remindersCount(int count);

  /// No description provided for @planNoun.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{plan} other{plans}}'**
  String planNoun(int count);

  /// No description provided for @reminderNoun.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{reminder} other{reminders}}'**
  String reminderNoun(int count);

  /// No description provided for @noSchedule.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled'**
  String get noSchedule;

  /// No description provided for @toggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get toggleSidebar;

  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Show main window'**
  String get trayShow;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @notifActionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get notifActionDone;

  /// No description provided for @notifActionRemind.
  ///
  /// In en, this message translates to:
  /// **'In 10 minutes'**
  String get notifActionRemind;

  /// No description provided for @navReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get navReminders;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders & Plans'**
  String get remindersTitle;

  /// No description provided for @remindersOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get remindersOverdue;

  /// No description provided for @remindersToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get remindersToday;

  /// No description provided for @remindersThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get remindersThisWeek;

  /// No description provided for @remindersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet'**
  String get remindersEmptyTitle;

  /// No description provided for @remindersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add a reminder or plan to get started.'**
  String get remindersEmptyBody;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get manageCategories;

  /// No description provided for @newCategory.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get newCategory;

  /// No description provided for @newCategoryName.
  ///
  /// In en, this message translates to:
  /// **'New category name'**
  String get newCategoryName;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @categoryNameExists.
  ///
  /// In en, this message translates to:
  /// **'A category with this name already exists'**
  String get categoryNameExists;

  /// No description provided for @viewCompletedShort.
  ///
  /// In en, this message translates to:
  /// **'View completed'**
  String get viewCompletedShort;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @restOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Rest of month'**
  String get restOfMonth;

  /// No description provided for @futureMonths.
  ///
  /// In en, this message translates to:
  /// **'Next 6 months'**
  String get futureMonths;

  /// No description provided for @completedChip.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedChip;

  /// No description provided for @showLeftPanel.
  ///
  /// In en, this message translates to:
  /// **'Show calendar panel'**
  String get showLeftPanel;

  /// No description provided for @hideLeftPanel.
  ///
  /// In en, this message translates to:
  /// **'Hide calendar panel'**
  String get hideLeftPanel;

  /// No description provided for @notificationChannelSound.
  ///
  /// In en, this message translates to:
  /// **'Reminders (sound)'**
  String get notificationChannelSound;

  /// No description provided for @notificationChannelSilent.
  ///
  /// In en, this message translates to:
  /// **'Reminders (silent)'**
  String get notificationChannelSilent;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Tempolet reminders and plans'**
  String get notificationChannelDescription;

  /// No description provided for @notificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Notification permission'**
  String get notificationPermission;

  /// No description provided for @notificationOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get notificationOff;

  /// No description provided for @notificationClosedBySystem.
  ///
  /// In en, this message translates to:
  /// **'Notifications were turned off by the system'**
  String get notificationClosedBySystem;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get openSystemSettings;

  /// No description provided for @exactAlarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exact reminders'**
  String get exactAlarmTitle;

  /// No description provided for @exactAlarmHint.
  ///
  /// In en, this message translates to:
  /// **'The system limits exact alarms; reminders may be delayed'**
  String get exactAlarmHint;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @advancedHide.
  ///
  /// In en, this message translates to:
  /// **'Hide advanced'**
  String get advancedHide;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get editCategory;

  /// No description provided for @discardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChangesTitle;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @monthPreviewMore.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String monthPreviewMore(int count);

  /// No description provided for @sidebarEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No schedule'**
  String get sidebarEmptyTitle;

  /// No description provided for @sidebarEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add a reminder or plan to start the day.'**
  String get sidebarEmptyHint;

  /// No description provided for @plansGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get plansGroupTitle;

  /// No description provided for @remindersGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersGroupTitle;

  /// No description provided for @dayOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Day overview'**
  String get dayOverviewTitle;

  /// No description provided for @tomorrowPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow preview'**
  String get tomorrowPreviewTitle;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
