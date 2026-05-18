import 'package:flutter/material.dart';

class GutterStyle {
  /// Width of the line number column.
  final double width;

  /// Alignment of the numbers in the column.
  final TextAlign textAlign;

  /// Style of the numbers.
  ///
  /// [TextStyle.fontSize] and [TextStyle.fontFamily] are ignored
  /// and taken from the widget style or [TextTheme.titleMedium] for consistency
  /// with lines. Everything else applies.
  ///
  /// Of omitted, the widget or theme value is used with the color of
  /// half the opacity.
  final TextStyle? textStyle;

  /// Style of the currently active line number.
  final TextStyle? activeLineTextStyle;

  /// Style of the error popup.
  final TextStyle? errorPopupTextStyle;

  /// Background of the line number column.
  final Color? background;

  /// Background for the currently active line number row.
  final Color? activeLineBackground;

  /// Central horizontal margin between the numbers and the code.
  final double margin;

  /// Whether to show line numbers column.
  final bool showLineNumbers;

  /// Whether to show errors column.
  final bool showErrors;

  /// Whether to show folding handles column.
  final bool showFoldingHandles;

  /// Whether there is any column to show in gutter.
  bool get showGutter => showLineNumbers || showErrors || showFoldingHandles;

  const GutterStyle({
    this.margin = 10.0,
    this.textAlign = TextAlign.right,
    this.showErrors = true,
    this.showFoldingHandles = true,
    this.showLineNumbers = true,
    this.width = 80.0,
    this.background,
    this.activeLineBackground,
    this.errorPopupTextStyle,
    this.textStyle,
    this.activeLineTextStyle,
  });

  /// Hides the gutter entirely.
  ///
  /// Use this instead of all-`false` because new elements can be added
  /// to the gutter in the future versions.
  static const GutterStyle none = GutterStyle(
    showErrors: false,
    showFoldingHandles: false,
    showLineNumbers: false,
  );

  GutterStyle copyWith({
    double? width,
    TextStyle? errorPopupTextStyle,
    TextStyle? textStyle,
    TextStyle? activeLineTextStyle,
  }) =>
      GutterStyle(
        width: width ?? this.width,
        textAlign: textAlign,
        textStyle: textStyle ?? this.textStyle,
        activeLineTextStyle: activeLineTextStyle ?? this.activeLineTextStyle,
        errorPopupTextStyle: errorPopupTextStyle,
        background: background,
        activeLineBackground: activeLineBackground,
        margin: margin,
        showErrors: showErrors,
        showFoldingHandles: showFoldingHandles,
        showLineNumbers: showLineNumbers,
      );
}

@Deprecated('Renamed to GutterStyle')
typedef LineNumberStyle = GutterStyle;
