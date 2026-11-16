import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_settings.dart';

/// The accent row's only control: a 16px color dot that opens the picker
/// (design decision D30 — no preset swatches).
class AccentSwatch extends StatelessWidget {
  const AccentSwatch({super.key, required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}

/// Opens the custom accent picker. Returns the chosen color, or null when the
/// dialog was cancelled.
Future<Color?> showAccentColorPicker(
  BuildContext context, {
  required Color initial,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _AccentColorPickerDialog(initial: initial),
  );
}

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}

class _AccentColorPickerDialog extends StatefulWidget {
  const _AccentColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_AccentColorPickerDialog> createState() =>
      _AccentColorPickerDialogState();
}

class _AccentColorPickerDialogState extends State<_AccentColorPickerDialog> {
  static const double _svHeight = 150;

  late HSVColor _hsv;
  late Color _color;

  final _r = TextEditingController();
  final _g = TextEditingController();
  final _b = TextEditingController();
  final _hex = TextEditingController();
  final _rFocus = FocusNode();
  final _gFocus = FocusNode();
  final _bFocus = FocusNode();
  final _hexFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _color = widget.initial.withValues(alpha: 1);
    _hsv = HSVColor.fromColor(_color);
    _syncFields(force: true);
  }

  @override
  void dispose() {
    _r.dispose();
    _g.dispose();
    _b.dispose();
    _hex.dispose();
    _rFocus.dispose();
    _gFocus.dispose();
    _bFocus.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  (int, int, int) _rgb(Color color) {
    final argb = color.toARGB32();
    return ((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
  }

  String _hexOf(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _setText(
    TextEditingController controller,
    String text, {
    required bool force,
    required FocusNode focus,
  }) {
    if (!force && focus.hasFocus) return;
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Pushes the current color into the inputs, leaving the field the user is
  /// typing in untouched ([force] overrides that for "restore default").
  void _syncFields({bool force = false}) {
    final (r, g, b) = _rgb(_color);
    _setText(_r, '$r', force: force, focus: _rFocus);
    _setText(_g, '$g', force: force, focus: _gFocus);
    _setText(_b, '$b', force: force, focus: _bFocus);
    _setText(_hex, _hexOf(_color), force: force, focus: _hexFocus);
  }

  void _applyHsv(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      _color = hsv.toColor();
    });
    _syncFields();
  }

  void _applyColor(Color color) {
    final opaque = color.withValues(alpha: 1);
    setState(() {
      _color = opaque;
      _hsv = HSVColor.fromColor(opaque);
    });
    _syncFields();
  }

  void _updateSv(Offset position, Size size) {
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - position.dy / size.height).clamp(0.0, 1.0);
    _applyHsv(HSVColor.fromAHSV(1, _hsv.hue, saturation, value));
  }

  void _updateHue(Offset position, double width) {
    final hue = (position.dx / width * 360).clamp(0.0, 359.999);
    _applyHsv(HSVColor.fromAHSV(1, hue, _hsv.saturation, _hsv.value));
  }

  void _onRgbChanged() {
    final rgb = (
      (int.tryParse(_r.text) ?? 0).clamp(0, 255),
      (int.tryParse(_g.text) ?? 0).clamp(0, 255),
      (int.tryParse(_b.text) ?? 0).clamp(0, 255),
    );
    _applyColor(Color.fromARGB(255, rgb.$1, rgb.$2, rgb.$3));
  }

  void _onHexChanged() {
    final raw = _hex.text.replaceAll('#', '').trim();
    if (raw.length != 6) return;
    final value = int.tryParse(raw, radix: 16);
    if (value == null) return;
    _applyColor(Color(0xFF000000 | value));
  }

  void _restoreDefault() {
    setState(() {
      _color = defaultAccent;
      _hsv = HSVColor.fromColor(defaultAccent);
    });
    _syncFields(force: true);
  }

  InputDecoration _fieldDecoration(AppPalette palette) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.field),
      borderSide: BorderSide(color: color),
    );
    return InputDecoration(
      isDense: true,
      counterText: '',
      filled: true,
      fillColor: palette.chip,
      contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      enabledBorder: border(palette.lineStrong),
      focusedBorder: border(palette.accent),
      border: border(palette.lineStrong),
    );
  }

  Widget _byteField({
    required String fieldKey,
    required String label,
    required TextEditingController controller,
    required FocusNode focus,
    required AppPalette palette,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: palette.sub),
          ),
          const SizedBox(height: 4),
          TextField(
            key: ValueKey(fieldKey),
            controller: controller,
            focusNode: focus,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 3,
            style: AppTextStyles.secondary.copyWith(color: palette.ink),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) => _onRgbChanged(),
            decoration: _fieldDecoration(palette),
          ),
        ],
      ),
    );
  }

  Widget _svSquare() {
    return SizedBox(
      height: _svHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, _svHeight);
          return GestureDetector(
            key: const ValueKey('color-sv'),
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) => _updateSv(details.localPosition, size),
            onPanUpdate: (details) => _updateSv(details.localPosition, size),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.block),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _hsv.saturation * size.width - 5,
                    top: (1 - _hsv.value) * size.height - 5,
                    child: IgnorePointer(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _color,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: kCardShadow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hueStrip() {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            key: const ValueKey('color-hue'),
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) => _updateHue(details.localPosition, width),
            onPanUpdate: (details) => _updateHue(details.localPosition, width),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      for (var i = 0; i <= 6; i++)
                        HSVColor.fromAHSV(
                          1,
                          (i * 60.0) % 360.0,
                          1,
                          1,
                        ).toColor(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = _paletteOf(context);

    return Dialog(
      key: const ValueKey('color-picker'),
      backgroundColor: palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.dialog),
      ),
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    l10n.customColor,
                    style: AppTextStyles.headline.copyWith(color: palette.ink),
                  ),
                  const Spacer(),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.lineStrong),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _svSquare(),
              const SizedBox(height: 12),
              _hueStrip(),
              const SizedBox(height: 14),
              Row(
                children: [
                  _byteField(
                    fieldKey: 'color-r',
                    label: 'R',
                    controller: _r,
                    focus: _rFocus,
                    palette: palette,
                  ),
                  const SizedBox(width: 8),
                  _byteField(
                    fieldKey: 'color-g',
                    label: 'G',
                    controller: _g,
                    focus: _gFocus,
                    palette: palette,
                  ),
                  const SizedBox(width: 8),
                  _byteField(
                    fieldKey: 'color-b',
                    label: 'B',
                    controller: _b,
                    focus: _bFocus,
                    palette: palette,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'HEX',
                style: AppTextStyles.caption.copyWith(color: palette.sub),
              ),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('color-hex'),
                controller: _hex,
                focusNode: _hexFocus,
                maxLength: 7,
                style: AppTextStyles.secondary.copyWith(color: palette.ink),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[#0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: (_) => _onHexChanged(),
                decoration: _fieldDecoration(palette),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const ValueKey('color-restore'),
                        onPressed: _restoreDefault,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.sub,
                          textStyle: AppTextStyles.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.restoreDefault,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('color-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.sub,
                      textStyle: AppTextStyles.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('color-confirm'),
                    onPressed: () => Navigator.of(context).pop(_color),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: Colors.white,
                      textStyle: AppTextStyles.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.confirm),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
