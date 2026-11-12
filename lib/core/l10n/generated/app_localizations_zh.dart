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
}
