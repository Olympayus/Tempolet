import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/app_tokens.dart';
import 'app_buttons.dart';

/// Colour wheel used by the category editor: a saturation/value square, a hue
/// strip, and an 「高级」 disclosure that opens direct R/G/B and HEX entry.
///
/// The accent picker in settings paints the same square; it stays separate
/// because it also owns a dialog, a restore-default action and sheet-vs-dialog
/// keying.
class ColorWheelPicker extends StatefulWidget {
  const ColorWheelPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.keyPrefix = 'color-wheel',
    this.enabled = true,
  });

  final Color initial;
  final ValueChanged<Color> onChanged;
  final String keyPrefix;
  final bool enabled;

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  static const double _svHeight = 132;
  static const double _hueHeight = 14;

  late HSVColor _hsv;
  late Color _color;
  bool _advanced = false;

  final _r = TextEditingController();
  final _g = TextEditingController();
  final _b = TextEditingController();
  final _hex = TextEditingController();
  final _rFocus = FocusNode();
  final _gFocus = FocusNode();
  final _bFocus = FocusNode();
  final _hexFocus = FocusNode();

  String _key(String suffix) => '${widget.keyPrefix}-$suffix';

  @override
  void initState() {
    super.initState();
    _color = widget.initial.withValues(alpha: 1);
    _hsv = HSVColor.fromColor(_color);
    _syncFields(force: true);
  }

  @override
  void didUpdateWidget(ColorWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow an externally chosen colour (e.g. the default for a new
    // category) without fighting the user's touch.
    final next = widget.initial.withValues(alpha: 1);
    if (next.toARGB32() != _color.toARGB32()) _applyColor(next);
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

  String _hexOf(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

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

  void _syncFields({bool force = false}) {
    final (r, g, b) = _rgb(_color);
    _setText(_r, '$r', force: force, focus: _rFocus);
    _setText(_g, '$g', force: force, focus: _gFocus);
    _setText(_b, '$b', force: force, focus: _bFocus);
    _setText(_hex, _hexOf(_color), force: force, focus: _hexFocus);
  }

  void _applyHsv(HSVColor hsv) {
    final color = hsv.toColor();
    setState(() {
      _hsv = hsv;
      _color = color;
    });
    widget.onChanged(color);
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
    if (!widget.enabled) return;
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - position.dy / size.height).clamp(0.0, 1.0);
    _applyHsv(HSVColor.fromAHSV(1, _hsv.hue, saturation, value));
  }

  void _updateHue(Offset position, double width) {
    if (!widget.enabled) return;
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
    widget.onChanged(_color);
  }

  void _onHexChanged() {
    final raw = _hex.text.replaceAll('#', '').trim();
    if (raw.length != 6) return;
    final value = int.tryParse(raw, radix: 16);
    if (value == null) return;
    _applyColor(Color(0xFF000000 | value));
    widget.onChanged(_color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);

    return Column(
      key: ValueKey(_key('picker')),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _svSquare(),
        const SizedBox(height: 10),
        _hueStrip(),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _color,
                shape: BoxShape.circle,
                border: Border.all(color: palette.lineStrong),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _hexOf(_color),
              key: ValueKey(_key('value')),
              style: AppTextStyles.caption.copyWith(color: palette.sub),
            ),
            const Spacer(),
            // 「高级」 sits on the wheel row, as requested: it opens the
            // direct RGB/HEX entry.
            AppButton.textLink(
              key: ValueKey(_key('advanced')),
              label: _advanced ? l10n.advancedHide : l10n.advanced,
              onPressed: () => setState(() => _advanced = !_advanced),
            ),
          ],
        ),
        if (_advanced) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              _byteField('r', 'R', _r, _rFocus, palette),
              const SizedBox(width: 8),
              _byteField('g', 'G', _g, _gFocus, palette),
              const SizedBox(width: 8),
              _byteField('b', 'B', _b, _bFocus, palette),
              const SizedBox(width: 8),
              // Labelled like R/G/B so the four fields share one baseline.
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HEX',
                      style: AppTextStyles.caption.copyWith(color: palette.sub),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      key: ValueKey(_key('hex')),
                      controller: _hex,
                      focusNode: _hexFocus,
                      maxLength: 7,
                      style: AppTextStyles.secondary.copyWith(
                        color: palette.ink,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp('[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      onChanged: (_) => _onHexChanged(),
                      decoration: _fieldDecoration(palette),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _svSquare() {
    return SizedBox(
      height: _svHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, _svHeight);
          return GestureDetector(
            key: ValueKey(_key('sv')),
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _updateSv(d.localPosition, size),
            onPanUpdate: (d) => _updateSv(d.localPosition, size),
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
                    left: (_hsv.saturation * size.width - 8).clamp(
                      0.0,
                      size.width - 16,
                    ),
                    top: ((1 - _hsv.value) * size.height - 8).clamp(
                      0.0,
                      size.height - 16,
                    ),
                    child: IgnorePointer(
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
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
      height: _hueHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            key: ValueKey(_key('hue')),
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _updateHue(d.localPosition, width),
            onPanUpdate: (d) => _updateHue(d.localPosition, width),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_hueHeight / 2),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (_hsv.hue / 360 * width - 2).clamp(0.0, width - 4),
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.black12),
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

  Widget _byteField(
    String suffix,
    String label,
    TextEditingController controller,
    FocusNode focus,
    AppPalette palette,
  ) {
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
            key: ValueKey(_key(suffix)),
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
}
