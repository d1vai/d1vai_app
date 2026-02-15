import 'package:flutter/material.dart';

class WebSubPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WebSubPageAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.centerTitle,
    this.onClose,
    this.closeTooltip = 'Close',
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final VoidCallback? onClose;
  final String closeTooltip;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: closeTooltip,
        icon: const Icon(Icons.close),
        onPressed: onClose ?? () => Navigator.of(context).maybePop(),
      ),
      title: title,
      centerTitle: centerTitle,
      actions: actions,
      bottom: bottom,
    );
  }
}
