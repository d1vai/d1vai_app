import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SnackBarPosition { bottom, top }

class SnackBarHelper {
  static OverlayEntry? _topToastEntry;
  static Timer? _topToastTimer;

  static void _triggerHaptic(ContentType type) {
    try {
      switch (type) {
        case ContentType.success:
          HapticFeedback.lightImpact();
          break;
        case ContentType.failure:
          HapticFeedback.mediumImpact();
          break;
        case ContentType.warning:
          HapticFeedback.selectionClick();
          break;
        case ContentType.help:
          HapticFeedback.selectionClick();
          break;
      }
    } catch (_) {}
  }

  static void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.success,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
      position: position,
    );
  }

  static void showError(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.failure,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
      position: position,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.warning,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
      position: position,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _showSnackBar(
      context,
      title: title,
      message: message,
      contentType: ContentType.help,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration,
      position: position,
    );
  }

  static void _clearTopToast() {
    _topToastTimer?.cancel();
    _topToastTimer = null;
    _topToastEntry?.remove();
    _topToastEntry = null;
  }

  static void _showTopToast(
    BuildContext context, {
    required String title,
    required String message,
    required ContentType contentType,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
  }) {
    _clearTopToast();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final visual = _snackVisual(Theme.of(context), contentType);
    final stamp = DateTime.now().millisecondsSinceEpoch;

    final entry = OverlayEntry(
      builder: (overlayContext) {
        final topInset = MediaQuery.of(overlayContext).padding.top;
        return Positioned(
          top: topInset + 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('toast:$stamp'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  return Opacity(
                    opacity: t.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * -12),
                      child: child,
                    ),
                  );
                },
                child: _FeedbackCard(
                  title: title,
                  message: message,
                  visual: visual,
                  actionLabel: actionLabel,
                  onActionPressed: onActionPressed == null
                      ? null
                      : () {
                          _clearTopToast();
                          onActionPressed();
                        },
                  onClose: _clearTopToast,
                ),
              ),
            ),
          ),
        );
      },
    );

    _topToastEntry = entry;
    overlay.insert(entry);
    _topToastTimer = Timer(
      duration ?? const Duration(seconds: 3),
      _clearTopToast,
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String title,
    required String message,
    required ContentType contentType,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
    SnackBarPosition position = SnackBarPosition.bottom,
  }) {
    _triggerHaptic(contentType);

    if (position == SnackBarPosition.top) {
      _showTopToast(
        context,
        title: title,
        message: message,
        contentType: contentType,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
        duration: duration,
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final visual = _snackVisual(Theme.of(context), contentType);
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: duration ?? const Duration(seconds: 4),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.zero,
        content: _FeedbackCard(
          title: title,
          message: message,
          visual: visual,
          actionLabel: actionLabel,
          onActionPressed: actionLabel != null && onActionPressed != null
              ? () {
                  messenger.hideCurrentSnackBar();
                  onActionPressed();
                }
              : null,
        ),
      ),
    );
  }

  static _SnackVisual _snackVisual(ThemeData theme, ContentType contentType) {
    switch (contentType) {
      case ContentType.success:
        return _SnackVisual(
          accent: const Color(0xFF10B981),
          accentSoft: const Color(0xFFECFDF5),
          icon: Icons.check_circle_outline_rounded,
        );
      case ContentType.failure:
        return _SnackVisual(
          accent: theme.colorScheme.error,
          accentSoft: const Color(0xFFFEF2F2),
          icon: Icons.error_outline_rounded,
        );
      case ContentType.warning:
        return _SnackVisual(
          accent: const Color(0xFFF59E0B),
          accentSoft: const Color(0xFFFFFBEB),
          icon: Icons.warning_amber_rounded,
        );
      case ContentType.help:
        return _SnackVisual(
          accent: theme.colorScheme.primary,
          accentSoft: const Color(0xFFF5F3FF),
          icon: Icons.info_outline_rounded,
        );
    }
    return _SnackVisual(
      accent: theme.colorScheme.primary,
      accentSoft: const Color(0xFFF5F3FF),
      icon: Icons.info_outline_rounded,
    );
  }
}

class _SnackVisual {
  const _SnackVisual({
    required this.accent,
    required this.accentSoft,
    required this.icon,
  });

  final Color accent;
  final Color accentSoft;
  final IconData icon;
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.title,
    required this.message,
    required this.visual,
    this.actionLabel,
    this.onActionPressed,
    this.onClose,
  });

  final String title;
  final String message;
  final _SnackVisual visual;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark
        ? Color.alphaBlend(
            visual.accent.withValues(alpha: 0.12),
            const Color(0xFF111827),
          )
        : Color.alphaBlend(visual.accent.withValues(alpha: 0.05), Colors.white);
    final edge = isDark
        ? visual.accent.withValues(alpha: 0.26)
        : Color.alphaBlend(
            visual.accent.withValues(alpha: 0.18),
            colorScheme.outlineVariant,
          );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            background,
            isDark
                ? Colors.white.withValues(alpha: 0.02)
                : visual.accentSoft.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: edge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  visual.accent.withValues(alpha: isDark ? 0.28 : 0.16),
                  visual.accent.withValues(alpha: isDark ? 0.12 : 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: visual.accent.withValues(alpha: isDark ? 0.24 : 0.16),
              ),
            ),
            child: Icon(visual.icon, size: 20, color: visual.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (onClose != null)
                      InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (actionLabel != null && onActionPressed != null) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: onActionPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: visual.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      backgroundColor: visual.accent.withValues(
                        alpha: isDark ? 0.12 : 0.08,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
