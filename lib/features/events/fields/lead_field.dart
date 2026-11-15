import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Reminder lead-time picker.
///
/// External semantics: null = no reminder, 0 = at the start, N = minutes before
/// (N may exceed 1440). The dropdown's "Custom…" entry uses an internal
/// sentinel; it never leaves this widget.
class LeadField extends StatefulWidget {
  const LeadField({super.key, this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<LeadField> createState() => _LeadFieldState();
}

class _LeadFieldState extends State<LeadField> {
  static const _customSentinel = -1;
  static const _presets = <int?>{null, 0, 5, 10, 30};

  late final TextEditingController _day;
  late final TextEditingController _hour;
  late final TextEditingController _minute;
  late final FocusNode _dayFocus;
  late final FocusNode _hourFocus;
  late final FocusNode _minuteFocus;
  int? _value;
  bool _customOpen = false;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _day = TextEditingController();
    _hour = TextEditingController();
    _minute = TextEditingController();
    _dayFocus = FocusNode()..addListener(_normalizeOnBlur);
    _hourFocus = FocusNode()..addListener(_normalizeOnBlur);
    _minuteFocus = FocusNode()..addListener(_normalizeOnBlur);
    _writeCustom(_value ?? 0);
  }

  @override
  void didUpdateWidget(LeadField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    _value = widget.value;
    if (_customOpen && !_fieldHasFocus) _writeCustom(_value ?? 0);
  }

  @override
  void dispose() {
    _day.dispose();
    _hour.dispose();
    _minute.dispose();
    _dayFocus.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  bool get _fieldHasFocus =>
      _dayFocus.hasFocus || _hourFocus.hasFocus || _minuteFocus.hasFocus;

  bool get _isPreset => _presets.contains(_value);

  int? get _dropdownValue => _customOpen ? _customSentinel : _value;

  void _writeCustom(int minutes) {
    final day = minutes ~/ 1440;
    final hour = (minutes % 1440) ~/ 60;
    final minute = minutes % 60;
    _setText(_day, '$day', focused: _dayFocus.hasFocus);
    _setText(_hour, '$hour', focused: _hourFocus.hasFocus);
    _setText(_minute, '$minute', focused: _minuteFocus.hasFocus);
  }

  void _setText(
    TextEditingController controller,
    String text, {
    required bool focused,
  }) {
    if (focused || controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _normalizeOnBlur() {
    if (_fieldHasFocus) return;
    _writeCustom(_value ?? 0);
  }

  void _onPresetSelected(int? next) {
    if (next == _customSentinel) {
      if (_customOpen) return;
      setState(() {
        _customOpen = true;
        _writeCustom(_value ?? 0);
      });
      return;
    }
    setState(() {
      _customOpen = false;
      _value = next;
    });
    widget.onChanged(next);
  }

  void _onCustomChanged() {
    final day = (int.tryParse(_day.text) ?? 0).clamp(0, 99);
    final hour = (int.tryParse(_hour.text) ?? 0).clamp(0, 23);
    final minute = (int.tryParse(_minute.text) ?? 0).clamp(0, 59);
    final next = day * 1440 + hour * 60 + minute;
    if (next == _value) return;
    _value = next;
    widget.onChanged(next);
  }

  String _formatLead(AppLocalizations l10n, int minutes) {
    if (minutes == 0) return l10n.remindAtStart;
    if (minutes < 60) return l10n.remindMinutesBefore(minutes);
    final day = minutes ~/ 1440;
    final hour = (minutes % 1440) ~/ 60;
    final minute = minutes % 60;
    final parts = <String>[
      if (day > 0) '$day${l10n.leadUnitDay}',
      if (hour > 0) '$hour${l10n.leadUnitHour}',
      if (minute > 0) '$minute${l10n.leadUnitMinute}',
    ];
    return parts.join(' ');
  }

  AppPalette _palette(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.brightness == Brightness.light
            ? AppPalette.light
            : AppPalette.dark)
        .withAccent(theme.colorScheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette(context);
    final l10n = AppLocalizations.of(context);
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem(value: null, child: Text(l10n.remindNone)),
      DropdownMenuItem(value: 0, child: Text(l10n.remindAtStart)),
      for (final minutes in const [5, 10, 30])
        DropdownMenuItem(
          value: minutes,
          child: Text(l10n.remindMinutesBefore(minutes)),
        ),
      if (_value != null && !_isPreset && _value != _customSentinel)
        DropdownMenuItem(
          value: _value,
          child: Text(_formatLead(l10n, _value!)),
        ),
      DropdownMenuItem(value: _customSentinel, child: Text(l10n.custom)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(AppRadii.field),
            border: Border.all(color: p.lineStrong),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              key: const ValueKey('lead-dropdown'),
              value: _dropdownValue,
              isDense: true,
              isExpanded: true,
              dropdownColor: p.card,
              icon: Icon(Icons.keyboard_arrow_down, size: 16, color: p.sub),
              style: AppTextStyles.secondary.copyWith(color: p.ink),
              items: items,
              onChanged: _onPresetSelected,
            ),
          ),
        ),
        if (_customOpen)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CustomSegment(
                  fieldKey: const ValueKey('lead-custom-day'),
                  controller: _day,
                  focusNode: _dayFocus,
                  palette: p,
                  onChanged: _onCustomChanged,
                ),
                _Unit(text: l10n.leadUnitDay, palette: p),
                _CustomSegment(
                  fieldKey: const ValueKey('lead-custom-hour'),
                  controller: _hour,
                  focusNode: _hourFocus,
                  palette: p,
                  onChanged: _onCustomChanged,
                ),
                _Unit(text: l10n.leadUnitHour, palette: p),
                _CustomSegment(
                  fieldKey: const ValueKey('lead-custom-minute'),
                  controller: _minute,
                  focusNode: _minuteFocus,
                  palette: p,
                  onChanged: _onCustomChanged,
                ),
                _Unit(text: l10n.leadUnitMinute, palette: p),
              ],
            ),
          ),
      ],
    );
  }
}

class _CustomSegment extends StatelessWidget {
  const _CustomSegment({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final AppPalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 2,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        style: AppTextStyles.secondary.copyWith(color: palette.ink),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          filled: true,
          fillColor: palette.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 7),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            borderSide: BorderSide(color: palette.lineStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            borderSide: BorderSide(color: palette.accent),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.field),
            borderSide: BorderSide(color: palette.lineStrong),
          ),
        ),
      ),
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit({required this.text, required this.palette});

  final String text;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(color: palette.sub),
      ),
    );
  }
}
