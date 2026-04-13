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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title?.trim().isNotEmpty == true ? title!.trim() : 'Share',
              style: theme.textTheme.titleMedium,
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                desc,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                link,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
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
                    icon: const Icon(Icons.link),
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
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
