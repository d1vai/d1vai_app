import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../sizes.dart';
import 'popup_controller.dart';

/// Popup window displaying the list of possible completions
class Popup extends StatefulWidget {
  final PopupController controller;
  final Size editingWindowSize;

  /// The window coordinates of the top-left corner of the editor widget.
  final Offset? editorOffset;

  /// The window coordinates of the highest allowed top-left corner
  /// of the popup if shown above the caret.
  ///
  /// Since the popup is pushed to the bottom of the allowed rectangle
  /// the actual position may be lower.
  final Offset flippedOffset;

  /// The window coordinates of the top-left corner of the popup
  /// if shown below the caret.
  final Offset normalOffset;

  final FocusNode parentFocusNode;
  final TextStyle style;
  final Color? backgroundColor;

  const Popup({
    super.key,
    required this.controller,
    required this.editingWindowSize,
    required this.editorOffset,
    required this.flippedOffset,
    required this.normalOffset,
    required this.parentFocusNode,
    required this.style,
    this.backgroundColor,
  });

  @override
  PopupState createState() => PopupState();
}

class PopupState extends State<Popup> {
  final pageStorageBucket = PageStorageBucket();

  @override
  void initState() {
    widget.controller.addListener(rebuild);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBackground =
        widget.backgroundColor ?? Theme.of(context).colorScheme.surface;
    final isDark = effectiveBackground.computeLuminance() < 0.4;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.12);
    final hoverColor =
        isDark ? const Color(0xFF2A2D2E) : const Color(0xFFF1F5F9);
    final selectedColor =
        isDark ? const Color(0xFF094771) : const Color(0xFFDCEBFA);
    final verticalFlipRequired = _isVerticalFlipRequired();
    final bool isHorizontalOverflowed = _isHorizontallyOverflowed();
    final double leftOffsetLimit =
        // TODO(nausharipov): find where 100 comes from
        widget.editingWindowSize.width -
            Sizes.autocompletePopupMaxWidth +
            (widget.editorOffset?.dx ?? 0) -
            100;

    // Fixes assertion error when ISC isn't attached but _attach method
    // of ISC instance are being called
    ItemScrollController? isc;
    if (widget.controller.itemScrollController.isAttached) {
      isc = widget.controller.itemScrollController;
    }

    return PageStorage(
      bucket: pageStorageBucket,
      child: Positioned(
        left: isHorizontalOverflowed ? leftOffsetLimit : widget.normalOffset.dx,
        top: verticalFlipRequired
            ? widget.flippedOffset.dy
            : widget.normalOffset.dy,
        child: Container(
          alignment: verticalFlipRequired
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          constraints: const BoxConstraints(
            maxHeight: Sizes.autocompletePopupMaxHeight,
            maxWidth: Sizes.autocompletePopupMaxWidth,
          ),
          // Container is used because the vertical borders
          // in DecoratedBox are hidden under scroll.
          // ignore: use_decorated_box
          child: Container(
            decoration: BoxDecoration(
              color: effectiveBackground,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ScrollablePositionedList.builder(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemScrollController: isc,
                      itemPositionsListener:
                          widget.controller.itemPositionsListener,
                      itemCount: widget.controller.suggestions.length,
                      itemBuilder: (context, index) {
                        return _buildListItem(
                          index,
                          hoverColor: hoverColor,
                          selectedColor: selectedColor,
                        );
                      },
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      border: Border(
                        top: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Text(
                      'Tab / Enter to insert',
                      style: widget.style.copyWith(
                        fontSize: (widget.style.fontSize ?? 12) - 1,
                        color: widget.style.color?.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isVerticalFlipRequired() {
    final isPopupShorterThanWindow =
        Sizes.autocompletePopupMaxHeight < widget.editingWindowSize.height;
    final isPopupOverflowingHeight = widget.normalOffset.dy +
            Sizes.autocompletePopupMaxHeight -
            (widget.editorOffset?.dy ?? 0) >
        widget.editingWindowSize.height;

    return isPopupOverflowingHeight && isPopupShorterThanWindow;
  }

  bool _isHorizontallyOverflowed() {
    return widget.normalOffset.dx -
            (widget.editorOffset?.dx ?? 0) +
            Sizes.autocompletePopupMaxWidth >
        widget.editingWindowSize.width;
  }

  Widget _buildListItem(
    int index, {
    required Color hoverColor,
    required Color selectedColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
        },
        onDoubleTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
          widget.controller.onCompletionSelected();
        },
        hoverColor: hoverColor,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ColoredBox(
          color: widget.controller.selectedIndex == index
              ? selectedColor
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.code,
                  size: 14,
                  color: widget.style.color?.withValues(alpha: 0.72),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.controller.suggestions[index],
                    overflow: TextOverflow.ellipsis,
                    style: widget.style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void rebuild() {
    setState(() {});
  }
}
