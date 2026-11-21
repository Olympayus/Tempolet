import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/layout_metrics.dart';
import 'package:tempolet/core/theme/app_tokens.dart';

void main() {
  test('metrics resolve phone, tablet tiers and desktop', () {
    expect(LayoutMetrics.resolve(AppLayout.phone, 375).row, 52);
    expect(LayoutMetrics.resolve(AppLayout.phone, 375).field, 40);
    expect(LayoutMetrics.resolve(AppLayout.tablet, 600).row, 48);
    expect(LayoutMetrics.resolve(AppLayout.tablet, 800).field, 42);
    expect(LayoutMetrics.resolve(AppLayout.tablet, 800).segment, 34);
    expect(LayoutMetrics.resolve(AppLayout.tablet, 1100).control, 40);
    expect(LayoutMetrics.resolve(AppLayout.desktop, 1280).row, AppSizes.row);
  });

  test('phone metrics keep the two-line row at 70', () {
    expect(LayoutMetrics.resolve(AppLayout.phone, 375).rowTall, 70);
  });

  test('tablet tiers split at 700 and 1000 shortest-side dp', () {
    expect(LayoutMetrics.resolve(AppLayout.tablet, 699).row, 48);
    expect(LayoutMetrics.resolve(AppLayout.tablet, 700).row, 52);
    expect(LayoutMetrics.resolve(AppLayout.tablet, 999).row, 52);
    expect(LayoutMetrics.resolve(AppLayout.tablet, 1000).row, 56);
  });

  test('desktop keeps the AppSizes tokens', () {
    final metrics = LayoutMetrics.resolve(AppLayout.desktop, 1280);
    expect(metrics.field, AppSizes.field);
    expect(metrics.rowTall, AppSizes.rowTall);
    expect(metrics.control, AppSizes.control);
    expect(metrics.segment, 28);
  });

  test('hit target floor is 44', () {
    expect(kMinHitTarget, 44);
  });

  test('resolveAppLayoutForSize uses the 600dp shortest-side breakpoint', () {
    expect(resolveAppLayoutForSize(const Size(375, 812)), AppLayout.phone);
    expect(
      resolveAppLayoutForSize(const Size(812, 375)),
      AppLayout.phone,
      reason: 'phone landscape stays on the phone shell',
    );
    expect(resolveAppLayoutForSize(const Size(599, 900)), AppLayout.phone);
    expect(resolveAppLayoutForSize(const Size(600, 900)), AppLayout.tablet);
    expect(resolveAppLayoutForSize(const Size(800, 1280)), AppLayout.tablet);
  });

  testWidgets('LayoutMetrics.of reads the resolved layout and shortest side', (
    tester,
  ) async {
    debugLayoutOverride = AppLayout.tablet;
    addTearDown(() => debugLayoutOverride = null);

    late LayoutMetrics metrics;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 1280)),
        child: Builder(
          builder: (context) {
            metrics = LayoutMetrics.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(metrics.row, 52);
    expect(metrics.field, 42);
  });
}
