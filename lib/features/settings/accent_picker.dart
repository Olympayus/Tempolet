import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';

/// Preset accents from the design spec §4.2 plus a custom RGB dialog.
class AccentPicker extends StatelessWidget {
  const AccentPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  static const presets = [
    Color(0xFF007AFF),
    Color(0xFFAF52DE),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFFFF2D55),
    Color(0xFFFF3B30),
  ];

  String _hex(Color color) =>
      '0x${color.toARGB32().toRadixString(16).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final preset in presets)
          InkWell(
            key: ValueKey('accent-${_hex(preset)}'),
            borderRadius: BorderRadius.circular(20),
            onTap: () => onSelected(preset),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: preset,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected.toARGB32() == preset.toARGB32()
                      ? scheme.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
        OutlinedButton(
          key: const ValueKey('accent-custom'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          ),
          onPressed: () => _openCustomDialog(context),
          child: Text(l10n.accentCustom,
              style: const TextStyle(fontSize: 11.5)),
        ),
      ],
    );
  }

  Future<void> _openCustomDialog(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => _RgbDialog(initial: selected),
    );
    if (picked != null) onSelected(picked);
  }
}

class _RgbDialog extends StatefulWidget {
  const _RgbDialog({required this.initial});

  final Color initial;

  @override
  State<_RgbDialog> createState() => _RgbDialogState();
}

class _RgbDialogState extends State<_RgbDialog> {
  late double _r;
  late double _g;
  late double _b;

  @override
  void initState() {
    super.initState();
    final color = widget.initial;
    _r = (color.r * 255).roundToDouble();
    _g = (color.g * 255).roundToDouble();
    _b = (color.b * 255).roundToDouble();
  }

  Color get _color => Color.fromARGB(255, _r.round(), _g.round(), _b.round());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget slider(String label, double value, Color active,
        ValueChanged<double> onChanged) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            child: Text(label, style: const TextStyle(fontSize: 11.5)),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 0,
              max: 255,
              activeColor: active,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 32,
            child: Text('${value.round()}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                )),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(l10n.accentColor, style: const TextStyle(fontSize: 15)),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 10),
            slider('R', _r, Colors.red, (v) => setState(() => _r = v)),
            slider('G', _g, Colors.green, (v) => setState(() => _g = v)),
            slider('B', _b, Colors.blue, (v) => setState(() => _b = v)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('rgb-confirm'),
          onPressed: () => Navigator.of(context).pop(_color),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
