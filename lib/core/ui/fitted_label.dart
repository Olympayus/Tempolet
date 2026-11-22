import 'package:flutter/material.dart';

/// A single-line label that scales down to fit instead of ellipsising.
///
/// Fixed interface copy — button and segment labels, page titles — must always
/// read in full: a longer translation or a narrower window shrinks the type
/// rather than cutting the word. User-entered content (event titles, category
/// names) keeps ellipsising, because it has no natural bound.
class FittedLabel extends StatelessWidget {
  const FittedLabel(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.alignment = Alignment.center,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  /// Where the label sits in the space it is given; keep it matching
  /// [textAlign] so the text does not drift when it shrinks.
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}
