// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Tempolet';

  @override
  String get navCalendar => '日历';

  @override
  String get navSettings => '设置';

  @override
  String get month => '月';

  @override
  String get week => '周';

  @override
  String get day => '日';

  @override
  String get today => '今天';

  @override
  String get newEvent => '新建事件';

  @override
  String get newReminder => '新建提醒';

  @override
  String get newPlan => '新建计划';

  @override
  String get eventTitle => '标题';

  @override
  String get eventNote => '备注';

  @override
  String get eventStart => '开始';

  @override
  String get eventEnd => '结束';

  @override
  String get eventDate => '日期';

  @override
  String get kindReminder => '提醒';

  @override
  String get kindPlan => '计划';

  @override
  String get importance => '重要程度';

  @override
  String get importanceHigh => '高';

  @override
  String get importanceMedium => '中';

  @override
  String get importanceLow => '低';

  @override
  String get remindAtStart => '开始时提醒';

  @override
  String remindMinutesBefore(int minutes) {
    return '提前 $minutes 分钟';
  }

  @override
  String get remindNone => '不提醒';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get reschedule => '改期';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get done => '完成';

  @override
  String get overdue => '超时';

  @override
  String get reminder => '提醒';

  @override
  String get allDone => '全部完成';

  @override
  String get noEvents => '暂无事件';

  @override
  String get allDay => '全天';

  @override
  String moreItems(int count) {
    return '+$count';
  }

  @override
  String hoverMoreItems(int count) {
    return '还有 $count 项';
  }

  @override
  String get settingsAppearance => '外观';

  @override
  String get themeMode => '主题';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get accentColor => '强调色';

  @override
  String get accentCustom => '自定义';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get settingsNotifications => '通知';

  @override
  String get defaultRemindOffset => '默认提前提醒';

  @override
  String get notificationSound => '通知声音';

  @override
  String get overdueSummary => '超时未完成次日汇总';

  @override
  String get notificationsRequireAppOpen => '通知需要应用保持运行';

  @override
  String get notificationsWindowsNote => 'Windows 不会弹权限请求；收不到提醒请在系统设置中允许通知';

  @override
  String get accentHint => '用于今天、选中状态与主按钮';

  @override
  String get defaultRemindHint => '新建提醒时默认使用的提前量';

  @override
  String get overdueSummaryHint => '每天早上汇总未完成事项';

  @override
  String get closeToTrayHint => '关闭窗口后继续在托盘运行';

  @override
  String get launchAtStartupHint => '登录 Windows 后自动启动';

  @override
  String get invalidTitle => '请输入标题';

  @override
  String get invalidTimeRange => '结束时间必须晚于开始时间';

  @override
  String get missingStart => '请选择开始时间';

  @override
  String get notifToday => '今天';

  @override
  String get notifStartingNow => '现在开始';

  @override
  String notifStartsIn(int minutes) {
    return '还有 $minutes 分钟开始';
  }

  @override
  String get notifOverdueTitle => '还有未完成的事项';

  @override
  String notifOverdueBody(int count) {
    return '昨天有 $count 项未完成';
  }

  @override
  String get settingsDesktop => '桌面';

  @override
  String get closeToTray => '关闭窗口时最小化到托盘';

  @override
  String get launchAtStartup => '开机自启';

  @override
  String get newItem => '新建';

  @override
  String get editItem => '编辑';

  @override
  String get create => '创建';

  @override
  String get dateLabel => '日期';

  @override
  String get yearUnit => '年';

  @override
  String get monthUnit => '月';

  @override
  String get dayUnit => '日';

  @override
  String get timeLabel => '时间';

  @override
  String get leadLabel => '提醒';

  @override
  String get leadHelp => '提前多久发送提醒';

  @override
  String get categoryLabel => '分类';

  @override
  String get categoryHelp => '用于标记与筛选';

  @override
  String get uncategorized => '未分类';

  @override
  String get noteOptional => '备注（可选）';

  @override
  String get custom => '自定义…';

  @override
  String get leadUnitDay => '日';

  @override
  String get leadUnitHour => '时';

  @override
  String get leadUnitMinute => '分';

  @override
  String get leadBeforeSuffix => '前';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
    );
    return '$_temp0';
  }

  @override
  String get viewCompleted => '查看已完成 ›';

  @override
  String get addReminderOrPlan => '＋ 添加提醒或计划';

  @override
  String get editInSidebar => '在侧栏中编辑 ›';

  @override
  String get completedTitle => '已完成';

  @override
  String completedAt(String date, String time) {
    return '$date $time 完成';
  }

  @override
  String get clear => '清空';

  @override
  String get restore => '恢复';

  @override
  String get select => '选择';

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '全部取消';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 项',
    );
    return '$_temp0';
  }

  @override
  String get completedEmptyTitle => '还没有已完成事项';

  @override
  String get completedEmptyHint => '完成后的事项会出现在这里';

  @override
  String get todayGroup => '今天';

  @override
  String get yesterdayGroup => '昨天';

  @override
  String get earlierGroup => '更早';

  @override
  String get deleteForeverHint => '删除后无法恢复';

  @override
  String get holidayBadge => '休';

  @override
  String get workdayBadge => '班';

  @override
  String get about => '关于';

  @override
  String get version => '版本';

  @override
  String get dataLocation => '数据文件位置';

  @override
  String get openFolder => '打开文件夹 ›';

  @override
  String get restoreDefault => '恢复默认';

  @override
  String get customColor => '自定义颜色';

  @override
  String get confirm => '确定';

  @override
  String get tomorrowPreview => '明日';

  @override
  String plansCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个计划',
    );
    return '$_temp0';
  }

  @override
  String remindersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个提醒',
    );
    return '$_temp0';
  }

  @override
  String planNoun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '个计划',
    );
    return '$_temp0';
  }

  @override
  String reminderNoun(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '个提醒',
    );
    return '$_temp0';
  }

  @override
  String get noSchedule => '无安排';

  @override
  String get toggleSidebar => '辅助栏';

  @override
  String get trayShow => '显示主窗口';

  @override
  String get trayQuit => '退出';

  @override
  String get notifActionDone => '完成';

  @override
  String get notifActionRemind => '10 分钟后提醒';

  @override
  String get navReminders => '提醒';

  @override
  String get remindersTitle => '提醒与计划';

  @override
  String get remindersOverdue => '逾期';

  @override
  String get remindersToday => '今日';

  @override
  String get remindersThisWeek => '本周';

  @override
  String get remindersEmptyTitle => '暂无提醒';

  @override
  String get remindersEmptyBody => '新建一条提醒或计划，开始规划。';

  @override
  String get manageCategories => '分类管理';

  @override
  String get newCategory => '新建分类';

  @override
  String get newCategoryName => '新分类名称';

  @override
  String get add => '添加';

  @override
  String get categoryNameExists => '分类名称已存在';

  @override
  String get viewCompletedShort => '查看已完成';

  @override
  String get filterAll => '全部';

  @override
  String get restOfMonth => '本月剩余';

  @override
  String get futureMonths => '未来 6 个月';

  @override
  String get completedChip => '查看已完成';

  @override
  String get showLeftPanel => '显示日历面板';

  @override
  String get hideLeftPanel => '隐藏日历面板';

  @override
  String get editCategory => '编辑分类';

  @override
  String get discardChangesTitle => '放弃修改？';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get discard => '放弃';

  @override
  String monthPreviewMore(int count) {
    return '还有 $count 项';
  }

  @override
  String get sidebarEmptyTitle => '无安排';

  @override
  String get sidebarEmptyHint => '添加提醒或计划，开始这一天。';

  @override
  String get plansGroupTitle => '计划';

  @override
  String get remindersGroupTitle => '提醒';

  @override
  String get dayOverviewTitle => '当日概览';

  @override
  String get tomorrowPreviewTitle => '次日预览';

  @override
  String get moreActions => '更多';
}
