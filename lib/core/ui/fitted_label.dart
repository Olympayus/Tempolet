import 'package:flutter/material.dart';

/// A label that keeps its full text instead of ellipsising.
///
/// Fixed interface copy — button and segment labels, page titles — must always
/// read in full, so it shrinks the type rather than cutting the word. Titles
/// pass [maxLines] > 1: they wrap at full size when the container lets them
/// grow, and only scale down when even that does not fit. User-entered content
/// (event titles, category names) keeps ellipsising, because it has no natural
/// bound.
class FittedLabel extends StatelessWidget {
  const FittedLabel(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.alignment = Alignment.center,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Where the label sits in the space it is given; keep it matching
  /// [textAlign] so the text does not drift when it shrinks.
  final Alignment alignment;

  /// Lines the label may use before it starts shrinking. Wrapping needs the
  /// parent to allow the extra height; with a bounded height the wrapped block
  /// is scaled down to fit.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (maxLines <= 1) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: _label(wrap: false),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Constrain the wrap width explicitly: a bare FittedBox would hand the
        // text unbounded width and it would never wrap.
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : null;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: SizedBox(width: width, child: _label(wrap: true)),
        );
      },
    );
  }

  Widget _label({required bool wrap}) => Text(
    text,
    maxLines: maxLines,
    softWrap: wrap,
    textAlign: textAlign,
    style: style,
  );
}
