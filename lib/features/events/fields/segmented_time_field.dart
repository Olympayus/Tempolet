import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_tokens.dart';

/// Segmented-field metrics from `docs/design/10-ui-refinement.md` §9.6.
const double _segmentHeight = 28;

/// Hour / minute segmented input.
///
/// [value] is minutes since midnight, or null when no time has been entered.
/// When [allowEndOfDay] is true (plan end fields) hour 24 is accepted, but only
/// with minute 00 — it renders as the 1440 end-of-day sentinel.
class SegmentedTimeField extends StatefulWidget {
  const SegmentedTimeField({
    super.key,
    this.value,
    required this.onChanged,
    this.allowEndOfDay = false,
    this.hourFieldKey,
    this.minuteFieldKey,
  });

  final int? value;
  final ValueChanged<int?> onChanged;
  final bool allowEndOfDay;
  final Key? hourFieldKey;
  final Key? minuteFieldKey;

  @override
  State<SegmentedTimeField> createState() => _SegmentedTimeFieldState();
}

class _SegmentedTimeFieldState extends State<SegmentedTimeField> {
  late final TextEditingController _hour;
  late final TextEditingController _minute;
  late final FocusNode _hourFocus;
  late final FocusNode _minuteFocus;
  int? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _hour = TextEditingController();
    _minute = TextEditingController();
    _hourFocus = FocusNode()..addListener(_normalizeOnBlur);
    _minuteFocus = FocusNode()..addListener(_normalizeOnBlur);
    _syncControllers();
  }

  @override
  void didUpdateWidget(SegmentedTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _value) return;
    _value = widget.value;
    _syncControllers();
  }

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final value = _value;
    final hourText = value == null ? '' : '${value ~/ 60}'.padLeft(2, '0');
    final minuteText = value == null ? '' : '${value % 60}'.padLeft(2, '0');
    _setText(_hour, hourText, focused: _hourFocus.hasFocus);
    _setText(_minute, minuteText, focused: _minuteFocus.hasFocus);
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
    if (_hourFocus.hasFocus || _minuteFocus.hasFocus) return;
    _syncControllers();
  }

  void _onSegmentChanged() {
    final hourText = _hour.text;
    final minuteText = _minute.text;
    if (hourText.isEmpty && minuteText.isEmpty) {
      _commit(null);
      return;
    }
    final hourValue = hourText.isEmpty ? 0 : int.tryParse(hourText);
    final minuteValue = minuteText.isEmpty ? 0 : int.tryParse(minuteText);
    if (hourValue == null || minuteValue == null) return;

    final maxHour = widget.allowEndOfDay ? 24 : 23;
    var hour = hourValue.clamp(0, maxHour);
    var minute = minuteValue.clamp(0, 59);
    if (hour == 24) {
      minute = 0;
      _setText(_minute, '00', focused: _minuteFocus.hasFocus);
    }
    _commit(hour * 60 + minute);
  }

  void _commit(int? next) {
    if (next == _value) return;
    _value = next;
    widget.onChanged(next);
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
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.tab): NextFocusIntent(),
      },
      child: FocusTraversalGroup(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Segment(
              fieldKey: widget.hourFieldKey,
              controller: _hour,
              focusNode: _hourFocus,
              palette: p,
              onChanged: _onSegmentChanged,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                ':',
                style: AppTextStyles.body.copyWith(color: p.sub),
              ),
            ),
            _Segment(
              fieldKey: widget.minuteFieldKey,
              controller: _minute,
              focusNode: _minuteFocus,
              palette: p,
              onChanged: _onSegmentChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.onChanged,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final AppPalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return SizedBox(
          width: 38,
          height: _segmentHeight,
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
            style: AppTextStyles.body.copyWith(color: palette.ink),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: '--',
              hintStyle: AppTextStyles.body.copyWith(color: palette.subWeak),
              filled: true,
              fillColor: focused ? kSelectedSegmentFill : palette.chip,
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: palette.lineStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: palette.accent),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.chip),
                borderSide: BorderSide(color: palette.lineStrong),
              ),
            ),
          ),
        );
      },
    );
  }
}
