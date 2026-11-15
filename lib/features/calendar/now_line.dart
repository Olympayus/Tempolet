import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Accent rule marking the current time in the day and week grids.
///
/// Rebuilds once a minute so the rule tracks wall-clock time. Pass [now] in
/// tests to pin the clock and skip the periodic timer.
class NowLine extends StatefulWidget {
  const NowLine({super.key, this.now});

  final DateTime? now;

  @override
  State<NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<NowLine> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: palette.accent,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(child: Container(height: 1, color: palette.accent)),
      ],
    );
  }
}
