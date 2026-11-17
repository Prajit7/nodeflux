import 'package:flutter/material.dart';

/// Colours used by the canvas and default widgets. Register on your
/// [ThemeData.extensions] to customise; otherwise light/dark defaults are
/// picked from the ambient brightness.
@immutable
class FlowTheme extends ThemeExtension<FlowTheme> {
  const FlowTheme({
    required this.background,
    required this.dotColor,
    required this.nodeColor,
    required this.nodeBorder,
    required this.selection,
    required this.textColor,
    required this.mutedText,
    required this.edgeColor,
    required this.errorColor,
    required this.successColor,
  });

  factory FlowTheme.light() => const FlowTheme(
        background: Color(0xFFF6F7F9),
        dotColor: Color(0xFFCFD3DA),
        nodeColor: Color(0xFFFFFFFF),
        nodeBorder: Color(0xFFDFE2E8),
        selection: Color(0xFF3B5BDB),
        textColor: Color(0xFF1B1D22),
        mutedText: Color(0xFF6B7280),
        edgeColor: Color(0xFF8A93A3),
        errorColor: Color(0xFFE03131),
        successColor: Color(0xFF2F9E44),
      );

  factory FlowTheme.dark() => const FlowTheme(
        background: Color(0xFF111318),
        dotColor: Color(0xFF2B2F38),
        nodeColor: Color(0xFF1C1F26),
        nodeBorder: Color(0xFF2F343E),
        selection: Color(0xFF7C94FF),
        textColor: Color(0xFFE8EAEE),
        mutedText: Color(0xFF9AA1AD),
        edgeColor: Color(0xFF6B7383),
        errorColor: Color(0xFFFF6B6B),
        successColor: Color(0xFF51CF66),
      );

  static FlowTheme of(BuildContext context) {
    final t = Theme.of(context);
    return t.extension<FlowTheme>() ??
        (t.brightness == Brightness.dark
            ? FlowTheme.dark()
            : FlowTheme.light());
  }

  final Color background, dotColor, nodeColor, nodeBorder, selection;
  final Color textColor, mutedText, edgeColor, errorColor, successColor;

  @override
  FlowTheme copyWith({
    Color? background,
    Color? dotColor,
    Color? nodeColor,
    Color? nodeBorder,
    Color? selection,
    Color? textColor,
    Color? mutedText,
    Color? edgeColor,
    Color? errorColor,
    Color? successColor,
  }) =>
      FlowTheme(
        background: background ?? this.background,
        dotColor: dotColor ?? this.dotColor,
        nodeColor: nodeColor ?? this.nodeColor,
        nodeBorder: nodeBorder ?? this.nodeBorder,
        selection: selection ?? this.selection,
        textColor: textColor ?? this.textColor,
        mutedText: mutedText ?? this.mutedText,
        edgeColor: edgeColor ?? this.edgeColor,
        errorColor: errorColor ?? this.errorColor,
        successColor: successColor ?? this.successColor,
      );

  @override
  FlowTheme lerp(FlowTheme? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FlowTheme(
      background: l(background, other.background),
      dotColor: l(dotColor, other.dotColor),
      nodeColor: l(nodeColor, other.nodeColor),
      nodeBorder: l(nodeBorder, other.nodeBorder),
      selection: l(selection, other.selection),
      textColor: l(textColor, other.textColor),
      mutedText: l(mutedText, other.mutedText),
      edgeColor: l(edgeColor, other.edgeColor),
      errorColor: l(errorColor, other.errorColor),
      successColor: l(successColor, other.successColor),
    );
  }
}
