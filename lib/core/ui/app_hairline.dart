import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

const double _hairlineHeight = 1;

/// A 1px separator (`docs/design/01-tokens.md` §4).
///
/// Defaults to the `line` token; pass [color] for table rules (`lineStrong`)
/// or any other context-specific hairline.
class AppHairline extends StatelessWidget {
  const AppHairline({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _hairlineHeight,
      color: color ?? _paletteOf(context).line,
    );
  }
}

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}
