import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'snackbar_helper.dart';

/// Shared share/copy UI so screens don't re-implement share logic.
///
/// Today we share Web URLs as the canonical link (deep links can be added later).
class ShareSheet {
  static Future<void> show(
    BuildContext context, {
    required Uri url,
    String? title,
    String? message,
  }) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _ShareSheetBody(url: url, title: title, message: message);
      },
    );
  }
}

class ShareLinks {
  // Keep this centralized so future domain/deep-link changes are one-liners.
  static const String webBaseUrl = 'https://www.d1v.ai';
  static const String marketplaceBaseUrl = 'https://d1vai.com';

  // d1vai_app currently opens app detail via the marketplace domain.
  static Uri marketplaceAppBySlug(String slug) =>
      Uri.parse('$marketplaceBaseUrl/apps/$slug');

  static Uri communityPostBySlug(String slug) =>
      Uri.parse('$webBaseUrl/c/$slug');

  static Uri publicUserBySlug(String slug) => Uri.parse('$webBaseUrl/u/$slug');

  static Uri openApiDocs({String? prompt, String? spec}) => Uri(
    scheme: 'https',
    host: 'www.d1v.ai',
    path: '/openapi',
    queryParameters: {
      if ((prompt ?? '').trim().isNotEmpty) 'prompt': prompt!.trim(),
      if ((spec ?? '').trim().isNotEmpty) 'spec': spec!.trim(),
    },
  );
}

class _ShareSheetBody extends StatelessWidget {
  final Uri url;
  final String? title;
  final String? message;

  const _ShareSheetBody({required this.url, this.title, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final link = url.toString();
    final desc = (message ?? '').trim();
    final subject = (title ?? '').trim().isEmpty ? null : title!.trim();

    String textToShare() {
      if (desc.isEmpty) return link;
      return '$desc\n$link';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF0F172A),
                      const Color(0xFF151E31),
                      colorScheme.primary.withValues(alpha: 0.12),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF8FAFC),
                      const Color(0xFFFDF4FF),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colorScheme.outlineVariant.withValues(alpha: 0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : const Color(0xFFD7DCE5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.20),
                          colorScheme.primary.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      Icons.ios_share_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title?.trim().isNotEmpty == true
                              ? title!.trim()
                              : 'Share',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          desc.isNotEmpty
                              ? desc
                              : 'Send this link to your team or copy it for later.',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : colorScheme.outlineVariant.withValues(alpha: 0.75),
                  ),
                ),
                child: Text(
                  link,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: link));
                        if (!context.mounted) return;
                        SnackBarHelper.showSuccess(
                          context,
                          title: 'Copied',
                          message: 'Link copied to clipboard',
                        );
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.10)
                              : colorScheme.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Copy link'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Share.share(textToShare(), subject: subject);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_outward_rounded),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
