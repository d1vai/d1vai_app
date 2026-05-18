import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../gutter/gutter.dart';
import '../line_numbers/gutter_style.dart';
import '../search/widget/search_widget.dart';
import '../sizes.dart';
import '../wip/autocomplete/popup.dart';
import 'actions/comment_uncomment.dart';
import 'actions/enter_key.dart';
import 'actions/indent.dart';
import 'actions/outdent.dart';
import 'actions/search.dart';
import 'actions/tab.dart';
import 'code_controller.dart';
import 'default_styles.dart';
import 'js_workarounds/js_workarounds.dart';

final _shortcuts = <ShortcutActivator, Intent>{
  // Copy
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyC,
  ): CopySelectionTextIntent.copy,
  const SingleActivator(
    LogicalKeyboardKey.keyC,
    meta: true,
  ): CopySelectionTextIntent.copy,
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.insert,
  ): CopySelectionTextIntent.copy,

  // Cut
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyX,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyX,
    meta: true,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.delete,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),

  // Undo
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    meta: true,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),

  // Redo
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),

  // Indent
  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const IndentIntent(),

  // Outdent
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.tab,
  ): const OutdentIntent(),

  // Comment Uncomment
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.slash,
  ): const CommentUncommentIntent(),
  const SingleActivator(
    LogicalKeyboardKey.slash,
    meta: true,
  ): const CommentUncommentIntent(),

  // Search
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyF,
  ): const SearchIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: true,
  ): const SearchIntent(),

  // Dismiss
  LogicalKeySet(
    LogicalKeyboardKey.escape,
  ): const DismissIntent(),

  // EnterKey
  LogicalKeySet(
    LogicalKeyboardKey.enter,
  ): const EnterKeyIntent(),

  // TabKey
  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const TabKeyIntent(),
};

class CodeField extends StatefulWidget {
  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around
  /// or make the field scrollable horizontally.
  final bool wrap;

  /// A CodeController instance to apply
  /// language highlight, themeing and modifiers.
  final CodeController controller;

  /// An UndoHistoryController instance
  /// to control TextField history.
  final UndoHistoryController? undoController;

  @Deprecated('Use gutterStyle instead')
  final GutterStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// {@macro flutter.widgets.textField.smartDashesType}
  final SmartDashesType smartDashesType;

  /// {@macro flutter.widgets.textField.smartQuotesType}
  final SmartQuotesType smartQuotesType;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  ///
  /// This is just passed as a parameter to a [TextField].
  /// See also [CodeController.readOnly].
  final bool readOnly;

  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;
  final bool highlightCurrentLine;
  final Color? currentLineColor;
  final bool showIndentGuides;
  final Color? indentGuideColor;
  final Color? activeIndentGuideColor;
  final bool highlightBracketPairs;
  final Color? bracketPairColor;
  final List<int> rulers;
  final Color? rulerColor;

  @Deprecated('Use gutterStyle instead')
  final bool? lineNumbers;

  final GutterStyle gutterStyle;

  const CodeField({
    super.key,
    required this.controller,
    this.undoController,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.smartDashesType = SmartDashesType.disabled,
    this.smartQuotesType = SmartQuotesType.disabled,
    this.padding = EdgeInsets.zero,
    GutterStyle? gutterStyle,
    this.enabled,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    this.highlightCurrentLine = true,
    this.currentLineColor,
    this.showIndentGuides = false,
    this.indentGuideColor,
    this.activeIndentGuideColor,
    this.highlightBracketPairs = true,
    this.bracketPairColor,
    this.rulers = const [],
    this.rulerColor,
    @Deprecated('Use gutterStyle instead') this.lineNumbers,
    @Deprecated('Use gutterStyle instead')
    this.lineNumberStyle = const GutterStyle(),
  })  : assert(
            gutterStyle == null || lineNumbers == null,
            'Can not provide gutterStyle and lineNumbers at the same time. '
            'Please use gutterStyle and provide necessary columns to show/hide'),
        gutterStyle = gutterStyle ??
            ((lineNumbers == false) ? GutterStyle.none : lineNumberStyle);

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  ScrollController? _horizontalCodeScroll;
  final _codeFieldKey = GlobalKey();

  OverlayEntry? _suggestionsPopup;
  OverlayEntry? _searchPopup;
  Offset _normalPopupOffset = Offset.zero;
  Offset _flippedPopupOffset = Offset.zero;
  double painterWidth = 0;
  double painterHeight = 0;

  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';
  Size? windowSize;
  late TextStyle textStyle;
  Color? _backgroundCol;

  final _editorKey = GlobalKey();
  Offset? _editorOffset;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();
    _codeScroll?.addListener(rebuild);

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    widget.controller.searchController.addListener(
      _onSearchControllerChange,
    );
    _horizontalCodeScroll = ScrollController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.attach(context, onKeyEvent: _onKeyEvent);

    widget.controller.searchController.codeFieldFocusNode = _focusNode;

    // Workaround for disabling spellchecks in FireFox
    // https://github.com/akvelon/flutter-code-editor/issues/197
    disableSpellCheckIfWeb();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final double width = _codeFieldKey.currentContext!.size!.width;
      final double height = _codeFieldKey.currentContext!.size!.height;
      windowSize = Size(width, height);
    });
    _onTextChanged();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.searchController.codeFieldFocusNode = null;
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_updatePopupOffset);
    widget.controller.popupController.removeListener(_onPopupStateChanged);
    _suggestionsPopup?.remove();
    widget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );
    _searchPopup?.remove();
    _searchPopup = null;
    _numberScroll?.dispose();
    _codeScroll?.removeListener(rebuild);
    _codeScroll?.dispose();
    _horizontalCodeScroll?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_onTextChanged);
    oldWidget.controller.removeListener(_updatePopupOffset);
    oldWidget.controller.popupController.removeListener(_onPopupStateChanged);
    oldWidget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );

    widget.controller.searchController.codeFieldFocusNode = _focusNode;
    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    widget.controller.searchController.addListener(
      _onSearchControllerChange,
    );
  }

  void rebuild() {
    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        // For some reason _codeFieldKey.currentContext is null in tests
        // so check first.
        final context = _codeFieldKey.currentContext;
        if (context != null) {
          final double width = context.size!.width;
          final double height = context.size!.height;
          windowSize = Size(width, height);
        }
      });
    });
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = widget.controller.text.split('\n');
    final buf = <String>[];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }

    // Find longest line
    longestLine = '';
    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });

    if (_codeScroll != null && _editorKey.currentContext != null) {
      final box = _editorKey.currentContext!.findRenderObject() as RenderBox?;
      _editorOffset = box?.localToGlobal(Offset.zero);
      if (_editorOffset != null) {
        var fixedOffset = _editorOffset!;
        fixedOffset += Offset(0, _safeOffset(_codeScroll));
        _editorOffset = fixedOffset;
      }
    }

    rebuild();
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    if (widget.wrap) {
      return widget.expands
          ? codeField
          : ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: codeField,
            );
    }

    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: minWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ), // Add extra padding
          ),
          widget.expands ? Expanded(child: codeField) : codeField,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        right: widget.padding.right,
      ),
      scrollDirection: Axis.horizontal,
      controller: _horizontalCodeScroll,
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default color scheme
    const rootKey = 'root';

    final themeData = Theme.of(context);
    final styles = CodeTheme.of(context)?.styles;
    _backgroundCol = widget.background ??
        styles?[rootKey]?.backgroundColor ??
        DefaultStyles.backgroundColor;

    if (widget.decoration != null) {
      _backgroundCol = null;
    }

    final defaultTextStyle = TextStyle(
      color: styles?[rootKey]?.color ?? DefaultStyles.textColor,
      fontSize: themeData.textTheme.titleMedium?.fontSize,
      height: themeData.textTheme.titleMedium?.height,
    );

    textStyle = defaultTextStyle.merge(widget.textStyle);

    final textField = TextField(
      focusNode: _focusNode,
      scrollPadding: widget.padding,
      style: textStyle,
      smartDashesType: widget.smartDashesType,
      smartQuotesType: widget.smartQuotesType,
      controller: widget.controller,
      undoController: widget.undoController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      decoration: const InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: 16),
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      cursorColor: widget.cursorColor ?? defaultTextStyle.color,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
    );

    final codeField = Stack(
      children: [
        if (widget.showIndentGuides)
          Positioned.fill(
            child: IgnorePointer(
              child: _IndentGuides(
                controller: widget.controller,
                textStyle: textStyle,
                padding: widget.padding,
                color: widget.indentGuideColor ??
                    defaultTextStyle.color?.withValues(alpha: 0.10) ??
                    Colors.transparent,
                activeColor: widget.activeIndentGuideColor ??
                    defaultTextStyle.color?.withValues(alpha: 0.24) ??
                    Colors.transparent,
              ),
            ),
          ),
        if (widget.rulers.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: _RulersOverlay(
                rulers: widget.rulers,
                textStyle: textStyle,
                padding: widget.padding,
                color: widget.rulerColor ??
                    defaultTextStyle.color?.withValues(alpha: 0.12) ??
                    Colors.transparent,
              ),
            ),
          ),
        if (widget.highlightCurrentLine)
          Positioned.fill(
            child: IgnorePointer(
              child: _CurrentLineHighlight(
                top: _currentLineTop(),
                height: _currentLineHeight(),
                color: widget.currentLineColor ??
                    defaultTextStyle.color?.withValues(alpha: 0.08) ??
                    Colors.transparent,
              ),
            ),
          ),
        if (widget.highlightBracketPairs)
          Positioned.fill(
            child: IgnorePointer(
              child: _BracketPairHighlight(
                controller: widget.controller,
                textStyle: textStyle,
                color: widget.bracketPairColor ??
                    defaultTextStyle.color?.withValues(alpha: 0.22) ??
                    Colors.transparent,
              ),
            ),
          ),
        textField,
      ],
    );

    final editingField = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Control horizontal scrolling
          return _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
        },
      ),
    );

    return FocusableActionDetector(
      actions: widget.controller.actions,
      shortcuts: _shortcuts,
      child: Container(
        decoration: widget.decoration,
        color: _backgroundCol,
        key: _codeFieldKey,
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.gutterStyle.showGutter) _buildGutter(),
            Expanded(key: _editorKey, child: editingField),
          ],
        ),
      ),
    );
  }

  Widget _buildGutter() {
    final lineNumberSize = textStyle.fontSize;
    final lineNumberColor = widget.gutterStyle.textStyle?.color ??
        textStyle.color?.withValues(alpha: 0.5);
    final lineDigits =
        max(2, widget.controller.text.split('\n').length.toString().length);
    final charWidth = (textStyle.fontSize ?? 14) * 0.62;
    final lineNumberWidth = (lineDigits * charWidth) + 16;
    final issueColumnWidth = widget.gutterStyle.showErrors ? 16.0 : 0.0;
    final foldingColumnWidth =
        widget.gutterStyle.showFoldingHandles ? 16.0 : 0.0;
    final effectiveGutterWidth = max(
      widget.gutterStyle.width,
      lineNumberWidth + issueColumnWidth + foldingColumnWidth,
    );

    final lineNumberTextStyle =
        (widget.gutterStyle.textStyle ?? textStyle).copyWith(
      color: lineNumberColor,
      fontFamily: textStyle.fontFamily,
      fontSize: lineNumberSize,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final gutterStyle = widget.gutterStyle.copyWith(
      width: effectiveGutterWidth,
      textStyle: lineNumberTextStyle,
      activeLineTextStyle:
          (widget.gutterStyle.activeLineTextStyle ?? lineNumberTextStyle)
              .copyWith(fontWeight: FontWeight.w700),
      errorPopupTextStyle: widget.gutterStyle.errorPopupTextStyle ??
          CodeTheme.of(context)?.styles['root'] ??
          textStyle.copyWith(
            fontSize: DefaultStyles.errorPopupTextSize,
            backgroundColor: DefaultStyles.backgroundColor,
            fontStyle: DefaultStyles.fontStyle,
          ),
    );

    return GutterWidget(
      codeController: widget.controller,
      style: gutterStyle,
      scrollController: _numberScroll,
    );
  }

  void _updatePopupOffset() {
    final textPainter = _getTextPainter(widget.controller.text);
    final caretHeight = _getCaretHeight(textPainter);

    final leftOffset = _getPopupLeftOffset(textPainter);
    final normalTopOffset = _getPopupTopOffset(textPainter, caretHeight);
    final flippedTopOffset = normalTopOffset -
        (Sizes.autocompletePopupMaxHeight + caretHeight + Sizes.caretPadding);

    setState(() {
      _normalPopupOffset = Offset(leftOffset, normalTopOffset);
      _flippedPopupOffset = Offset(leftOffset, flippedTopOffset);
    });
  }

  TextPainter _getTextPainter(String text) {
    return TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: text, style: textStyle),
    )..layout();
  }

  Offset _getCaretOffset(TextPainter textPainter) {
    return textPainter.getOffsetForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
  }

  double _getCaretHeight(TextPainter textPainter) {
    final double? caretFullHeight = textPainter.getFullHeightForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
    return caretFullHeight ?? 0;
  }

  double _getPopupLeftOffset(TextPainter textPainter) {
    return max(
      _getCaretOffset(textPainter).dx +
          widget.padding.left -
          _safeOffset(_horizontalCodeScroll) * -1 +
          (_editorOffset?.dx ?? 0),
      0,
    );
  }

  double _getPopupTopOffset(TextPainter textPainter, double caretHeight) {
    return max(
      _getCaretOffset(textPainter).dy +
          caretHeight +
          16 +
          widget.padding.top -
          _safeOffset(_codeScroll) * -1 +
          (_editorOffset?.dy ?? 0),
      0,
    );
  }

  double _currentLineTop() {
    if (!widget.controller.selection.isValid ||
        widget.controller.selection.baseOffset < 0) {
      return -1000;
    }
    final textPainter = _getTextPainter(widget.controller.text);
    final caretOffset = _getCaretOffset(textPainter);
    return 16 + caretOffset.dy - _safeOffset(_codeScroll);
  }

  double _currentLineHeight() {
    final textPainter = _getTextPainter(widget.controller.text);
    final caretHeight = _getCaretHeight(textPainter);
    if (caretHeight > 0) return caretHeight;
    return (textStyle.fontSize ?? 14) * (textStyle.height ?? 1.3);
  }

  void _onPopupStateChanged() {
    final shouldShow =
        widget.controller.popupController.shouldShow && windowSize != null;
    if (!shouldShow) {
      _suggestionsPopup?.remove();
      _suggestionsPopup = null;
      return;
    }

    if (_suggestionsPopup == null) {
      _suggestionsPopup = _buildSuggestionOverlay();
      Overlay.of(context).insert(_suggestionsPopup!);
    }

    _suggestionsPopup!.markNeedsBuild();
  }

  void _onSearchControllerChange() {
    final shouldShow = widget.controller.searchController.shouldShow;

    if (!shouldShow) {
      _searchPopup?.remove();
      _searchPopup = null;
      return;
    }

    if (_searchPopup == null) {
      _searchPopup = _buildSearchOverlay();
      Overlay.of(context).insert(_searchPopup!);
    }
  }

  OverlayEntry _buildSearchOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withValues(alpha: 0.9);
    final backgroundColor = _backgroundCol ?? colorScheme.surface;
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 10,
          right: 10,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: borderColor,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: backgroundColor,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: SearchWidget(
                  searchController: widget.controller.searchController,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  OverlayEntry _buildSuggestionOverlay() {
    return OverlayEntry(
      builder: (context) {
        return Popup(
          normalOffset: _normalPopupOffset,
          flippedOffset: _flippedPopupOffset,
          controller: widget.controller.popupController,
          editingWindowSize: windowSize!,
          style: textStyle,
          backgroundColor: _backgroundCol,
          parentFocusNode: _focusNode!,
          editorOffset: _editorOffset,
        );
      },
    );
  }

  double _safeOffset(ScrollController? controller) {
    if (controller == null || !controller.hasClients) {
      return 0;
    }
    return controller.offset;
  }
}

class _CurrentLineHighlight extends StatelessWidget {
  final double top;
  final double height;
  final Color color;

  const _CurrentLineHighlight({
    required this.top,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (top < -500) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned(
          top: top,
          left: 0,
          right: 0,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color),
          ),
        ),
      ],
    );
  }
}

class _IndentGuides extends StatelessWidget {
  final CodeController controller;
  final TextStyle textStyle;
  final EdgeInsets padding;
  final Color color;
  final Color activeColor;

  const _IndentGuides({
    required this.controller,
    required this.textStyle,
    required this.padding,
    required this.color,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final lineHeight = (textStyle.fontSize ?? 14) * (textStyle.height ?? 1.3);
    final charWidth = (textStyle.fontSize ?? 14) * 0.62;
    final activeVisibleOffset =
        controller.selection.isValid && controller.selection.extentOffset >= 0
            ? controller.selection.extentOffset.clamp(0, controller.text.length)
            : 0;
    final activeFullOffset = controller.code.hiddenRanges.recoverPosition(
      activeVisibleOffset,
      placeHiddenRanges: TextAffinity.downstream,
    );
    final activeLineIndex = controller.code.lines.characterIndexToLineIndex(
      activeFullOffset,
    );
    final activeIndentLevel = _indentLevelForLine(activeLineIndex);
    final visibleLines = controller.code.hiddenLineRanges.visibleLineNumbers
        .toList(growable: false);

    return Stack(
      children: [
        for (var visibleIndex = 0;
            visibleIndex < visibleLines.length;
            visibleIndex++)
          ..._buildGuidesForVisibleLine(
            fullLineIndex: visibleLines[visibleIndex],
            visibleLineIndex: visibleIndex,
            lineHeight: lineHeight,
            charWidth: charWidth,
            activeIndentLevel: activeIndentLevel,
            activeLineIndex: activeLineIndex,
          ),
      ],
    );
  }

  List<Widget> _buildGuidesForVisibleLine({
    required int fullLineIndex,
    required int visibleLineIndex,
    required double lineHeight,
    required double charWidth,
    required int activeIndentLevel,
    required int activeLineIndex,
  }) {
    final indentLevel = _indentLevelForLine(fullLineIndex);
    if (indentLevel <= 0) return const [];

    final top = 16 + (visibleLineIndex * lineHeight);
    final isActiveLine = fullLineIndex == activeLineIndex;

    return List<Widget>.generate(indentLevel, (index) {
      final level = index + 1;
      return Positioned(
        top: top,
        bottom: null,
        left: padding.left + (charWidth * controller.params.tabSpaces * level),
        width: 1,
        height: lineHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isActiveLine && level == activeIndentLevel
                ? activeColor
                : color,
          ),
        ),
      );
    });
  }

  int _indentLevelForLine(int lineIndex) {
    final line = controller.code.lines.lines[lineIndex];
    if (line.text.trim().isEmpty) return 0;
    final tabSpaces = controller.params.tabSpaces;
    return line.indent ~/ tabSpaces;
  }
}

class _BracketPairHighlight extends StatelessWidget {
  final CodeController controller;
  final TextStyle textStyle;
  final Color color;

  const _BracketPairHighlight({
    required this.controller,
    required this.textStyle,
    required this.color,
  });

  static const _pairs = {
    '(': ')',
    '[': ']',
    '{': '}',
  };

  static const _reversePairs = {
    ')': '(',
    ']': '[',
    '}': '{',
  };

  @override
  Widget build(BuildContext context) {
    final selection = controller.selection;
    if (!selection.isValid || !selection.isCollapsed || selection.start < 0) {
      return const SizedBox.shrink();
    }

    final fullText = controller.code.text;
    final fullCursor = controller.code.hiddenRanges.recoverPosition(
      selection.extentOffset.clamp(0, controller.text.length),
      placeHiddenRanges: TextAffinity.downstream,
    );
    final activeIndex = _candidateBracketIndex(fullText, fullCursor);
    if (activeIndex == null) return const SizedBox.shrink();

    final activeChar = fullText[activeIndex];
    final matchIndex = _matchingBracketIndex(fullText, activeIndex, activeChar);
    if (matchIndex == null) return const SizedBox.shrink();

    final visibleActive = controller.code.hiddenRanges.cutPosition(activeIndex);
    final visibleMatch = controller.code.hiddenRanges.cutPosition(matchIndex);
    if (!_isVisibleBracket(fullText, activeIndex, visibleActive) ||
        !_isVisibleBracket(fullText, matchIndex, visibleMatch)) {
      return const SizedBox.shrink();
    }

    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: controller.text, style: textStyle),
    )..layout();

    return Stack(
      children: [
        _buildHighlightForPosition(painter, visibleActive),
        _buildHighlightForPosition(painter, visibleMatch),
      ],
    );
  }

  Widget _buildHighlightForPosition(TextPainter painter, int visibleOffset) {
    final caretOffset = painter.getOffsetForCaret(
      TextPosition(offset: visibleOffset),
      Rect.zero,
    );
    final nextOffset = visibleOffset < controller.text.length
        ? painter.getOffsetForCaret(
            TextPosition(offset: visibleOffset + 1),
            Rect.zero,
          )
        : null;
    final charWidth = nextOffset == null
        ? (textStyle.fontSize ?? 14) * 0.62
        : (nextOffset.dx - caretOffset.dx).abs().clamp(
              1.0,
              (textStyle.fontSize ?? 14) * 1.2,
            );
    final charHeight = painter.getFullHeightForCaret(
      TextPosition(offset: visibleOffset),
      Rect.zero,
    );

    return Positioned(
      left: caretOffset.dx,
      top: 16 + caretOffset.dy,
      width: charWidth + 1,
      height: charHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color, width: 1),
        ),
      ),
    );
  }

  int? _candidateBracketIndex(String text, int cursor) {
    if (cursor > 0) {
      final previous = text[cursor - 1];
      if (_pairs.containsKey(previous) || _reversePairs.containsKey(previous)) {
        return cursor - 1;
      }
    }
    if (cursor < text.length) {
      final current = text[cursor];
      if (_pairs.containsKey(current) || _reversePairs.containsKey(current)) {
        return cursor;
      }
    }
    return null;
  }

  int? _matchingBracketIndex(String text, int index, String char) {
    if (_pairs.containsKey(char)) {
      final close = _pairs[char]!;
      var depth = 0;
      for (var i = index + 1; i < text.length; i++) {
        final current = text[i];
        if (current == char) depth++;
        if (current == close) {
          if (depth == 0) return i;
          depth--;
        }
      }
      return null;
    }

    final open = _reversePairs[char];
    if (open == null) return null;
    var depth = 0;
    for (var i = index - 1; i >= 0; i--) {
      final current = text[i];
      if (current == char) depth++;
      if (current == open) {
        if (depth == 0) return i;
        depth--;
      }
    }
    return null;
  }

  bool _isVisibleBracket(String fullText, int fullIndex, int visibleIndex) {
    if (visibleIndex < 0 || visibleIndex >= controller.text.length)
      return false;
    return controller.text[visibleIndex] == fullText[fullIndex];
  }
}

class _RulersOverlay extends StatelessWidget {
  final List<int> rulers;
  final TextStyle textStyle;
  final EdgeInsets padding;
  final Color color;

  const _RulersOverlay({
    required this.rulers,
    required this.textStyle,
    required this.padding,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final charWidth = (textStyle.fontSize ?? 14) * 0.62;
    return Stack(
      children: [
        for (final ruler in rulers)
          Positioned(
            top: 0,
            bottom: 0,
            left: padding.left + (charWidth * ruler),
            width: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: color),
            ),
          ),
      ],
    );
  }
}
