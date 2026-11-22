import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/layout.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_dropdown.dart';

/// Height of one custom numeric segment, matching `SegmentedDateField`.
const double _segmentHeight = 28;

/// Reminder lead-time picker.
///
/// External semantics: null = no reminder, 0 = at the start, N = minutes before
/// (N may exceed 1440). The dropdown's "Custom…" entry uses an internal
/// sentinel; it never leaves this widget.
class LeadField extends StatefulWidget {
  const LeadField({
    super.key,
    this.value,
    required this.onChanged,
    this.triggerHeight = AppSizes.field,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  /// Height of the preset dropdown's trigger; the editor aligns it with the
  /// 34px fields while settings uses its own 36px control height.
  final double triggerHeight;

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
      if (resolveAppLayout(context) == AppLayout.phone) {
        _openCustomSheet();
        return;
      }
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
    if (parts.isEmpty) return l10n.remindAtStart;
    return '${parts.join(' ')}${l10n.leadBeforeSuffix}';
  }

  AppPalette _palette(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.brightness == Brightness.light
            ? AppPalette.light
            : AppPalette.dark)
        .withAccent(theme.colorScheme.primary);
  }

  /// Phone custom lead panel (`v0.1.5 design` §8.8): the same day/hour/minute
  /// segments in a bottom sheet instead of the inline expansion.
  Future<void> _openCustomSheet() async {
    final p = _palette(context);
    final l10n = AppLocalizations.of(context);
    _writeCustom(_value ?? 0);
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        key: const ValueKey('lead-picker-sheet'),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.dialog),
          ),
        ),
        child: SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, setSheetState) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.custom,
                    style: AppTextStyles.headline.copyWith(color: p.ink),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _customSegments(p, l10n, setSheetState),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton.primary(
                      key: const ValueKey('lead-picker-confirm'),
                      label: l10n.confirm,
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(_value ?? 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _customOpen = false;
      _value = result;
    });
    widget.onChanged(result);
  }

  List<Widget> _customSegments(
    AppPalette p,
    AppLocalizations l10n,
    StateSetter refresh,
  ) {
    void changed() {
      _onCustomChanged();
      refresh(() {});
    }

    return [
      _CustomSegment(
        fieldKey: const ValueKey('lead-custom-day'),
        controller: _day,
        focusNode: _dayFocus,
        palette: p,
        onChanged: changed,
      ),
      _Unit(text: l10n.leadUnitDay, palette: p),
      _CustomSegment(
        fieldKey: const ValueKey('lead-custom-hour'),
        controller: _hour,
        focusNode: _hourFocus,
        palette: p,
        onChanged: changed,
      ),
      _Unit(text: l10n.leadUnitHour, palette: p),
      _CustomSegment(
        fieldKey: const ValueKey('lead-custom-minute'),
        controller: _minute,
        focusNode: _minuteFocus,
        palette: p,
        onChanged: changed,
      ),
      _Unit(text: l10n.leadUnitMinute, palette: p),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette(context);
    final l10n = AppLocalizations.of(context);
    final items = <AppDropdownItem<int?>>[
      AppDropdownItem(value: null, label: l10n.remindNone),
      AppDropdownItem(value: 0, label: l10n.remindAtStart),
      for (final minutes in const [5, 10, 30])
        AppDropdownItem(
          value: minutes,
          label: l10n.remindMinutesBefore(minutes),
        ),
      if (_value != null && !_isPreset && _value != _customSentinel)
        AppDropdownItem(value: _value, label: _formatLead(l10n, _value!)),
      AppDropdownItem(value: _customSentinel, label: l10n.custom),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDropdown<int?>(
          key: const ValueKey('lead-dropdown'),
          value: _dropdownValue,
          triggerHeight: widget.triggerHeight,
          semanticLabel: l10n.leadLabel,
          items: items,
          onChanged: _onPresetSelected,
        ),
        if (_customOpen)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _customSegments(p, l10n, setState),
              ),
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
      height: _segmentHeight,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusNode.hasFocus;
          return TextField(
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
          );
        },
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
