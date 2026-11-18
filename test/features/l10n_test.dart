import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';

void main() {
  group('english plurals', () {
    final en = lookupAppLocalizations(const Locale('en'));

    test('plansCount distinguishes one and many', () {
      expect(en.plansCount(1), '1 plan');
      expect(en.plansCount(2), '2 plans');
      expect(en.plansCount(0), '0 plans');
    });

    test('remindersCount distinguishes one and many', () {
      expect(en.remindersCount(1), '1 reminder');
      expect(en.remindersCount(2), '2 reminders');
    });

    test('itemsCount distinguishes one and many', () {
      expect(en.itemsCount(0), '0 items');
      expect(en.itemsCount(1), '1 item');
      expect(en.itemsCount(2), '2 items');
    });

    test('noun units used by the day overview pluralize alone', () {
      expect(en.planNoun(1), 'plan');
      expect(en.planNoun(2), 'plans');
      expect(en.reminderNoun(1), 'reminder');
      expect(en.reminderNoun(2), 'reminders');
    });

    test('selectedCount pluralizes its label', () {
      expect(en.selectedCount(1), '1 selected');
      expect(en.selectedCount(2), '2 selected');
    });
  });

  group('chinese does not distinguish plurals', () {
    final zh = lookupAppLocalizations(const Locale('zh'));

    test('counts keep the existing single form', () {
      expect(zh.plansCount(1), '1 个计划');
      expect(zh.plansCount(2), '2 个计划');
      expect(zh.plansCount(0), '0 个计划');
      expect(zh.remindersCount(1), '1 个提醒');
      expect(zh.remindersCount(2), '2 个提醒');
      expect(zh.itemsCount(0), '0 项');
      expect(zh.itemsCount(1), '1 项');
      expect(zh.itemsCount(2), '2 项');
    });

    test('noun units keep the existing single form', () {
      expect(zh.planNoun(1), '个计划');
      expect(zh.planNoun(2), '个计划');
      expect(zh.reminderNoun(1), '个提醒');
      expect(zh.reminderNoun(2), '个提醒');
    });

    test('selectedCount keeps the existing single form', () {
      expect(zh.selectedCount(1), '已选 1 项');
      expect(zh.selectedCount(2), '已选 2 项');
    });
  });

  group('v0.1.3 strings', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));

    test('sidebar and day overview copy is keyed', () {
      expect(en.completedChip, 'Completed');
      expect(zh.completedChip, '查看已完成');
      expect(en.sidebarEmptyTitle, 'No schedule');
      expect(zh.sidebarEmptyTitle, '无安排');
      expect(
        en.sidebarEmptyHint,
        'Add a reminder or plan to start the day.',
      );
      expect(zh.sidebarEmptyHint, '添加提醒或计划，开始这一天。');
      expect(en.plansGroupTitle, 'Plans');
      expect(zh.plansGroupTitle, '计划');
      expect(en.remindersGroupTitle, 'Reminders');
      expect(zh.remindersGroupTitle, '提醒');
      expect(en.dayOverviewTitle, 'Day overview');
      expect(zh.dayOverviewTitle, '当日概览');
      expect(en.tomorrowPreviewTitle, 'Tomorrow preview');
      expect(zh.tomorrowPreviewTitle, '次日预览');
    });
  });

  group('v0.1.4 strings', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));

    test('deselectAll is keyed in both languages', () {
      expect(en.deselectAll, 'Deselect all');
      expect(zh.deselectAll, '全部取消');
    });
  });
}
