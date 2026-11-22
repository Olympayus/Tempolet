import 'package:flutter/widgets.dart';

import 'layout.dart';
import 'theme/app_tokens.dart';

/// Minimum interactive target for touch layouts
/// (`docs/superpowers/specs/2026-11-20-tempolet-v0.1.5-design.md` §8.7).
const double kMinHitTarget = 44;

/// Row, field, control and segment heights for one layout tier.
///
/// Desktop keeps [AppSizes]; phones use the fixed touch density; tablets scale
/// by the shortest side in three tiers (design §8.7). `segment` has no
/// desktop `AppSizes` token, so 28 (the platform segmented-control visual
/// height) is the documented desktop default.
@immutable
class LayoutMetrics {
  const LayoutMetrics({
    required this.row,
    required this.field,
    required this.rowTall,
    required this.control,
    required this.segment,
  });

  /// Desktop density: identical to the pre-v0.1.5 `AppSizes` tokens.
  static const _desktop = LayoutMetrics(
    row: AppSizes.row,
    field: AppSizes.field,
    rowTall: AppSizes.rowTall,
    control: AppSizes.control,
    segment: 28,
  );

  /// Phone density. Controls keep their desktop visual height; touch code
  /// pads the hit area to [kMinHitTarget] (design §8.7).
  static const _phone = LayoutMetrics(
    row: 52,
    field: 40,
    rowTall: 70,
    control: AppSizes.control,
    segment: 28,
  );

  /// Tablet, shortest side < 700dp.
  static const _tabletSmall = LayoutMetrics(
    row: 48,
    field: 40,
    rowTall: 64,
    control: 36,
    segment: 32,
  );

  /// Tablet, shortest side 700–999dp.
  static const _tabletMedium = LayoutMetrics(
    row: 52,
    field: 42,
    rowTall: 68,
    control: 38,
    segment: 34,
  );

  /// Tablet, shortest side >= 1000dp.
  static const _tabletLarge = LayoutMetrics(
    row: 56,
    field: 44,
    rowTall: 72,
    control: 40,
    segment: 36,
  );

  /// Resolves the density for [layout], using [shortestSide] for tablet tiers.
  static LayoutMetrics resolve(AppLayout layout, double shortestSide) {
    switch (layout) {
      case AppLayout.desktop:
        return _desktop;
      case AppLayout.phone:
        return _phone;
      case AppLayout.tablet:
        if (shortestSide < 700) return _tabletSmall;
        if (shortestSide < 1000) return _tabletMedium;
        return _tabletLarge;
    }
  }

  /// Resolves the density from the ambient [BuildContext].
  static LayoutMetrics of(BuildContext context) => resolve(
    resolveAppLayout(context),
    MediaQuery.sizeOf(context).shortestSide,
  );

  /// List row height.
  final double row;

  /// Form field / input height.
  final double field;

  /// Two-line list row height (settings rows and similar).
  final double rowTall;

  /// Button and icon-button visual height.
  final double control;

  /// Segmented-control visual height.
  final double segment;
}
