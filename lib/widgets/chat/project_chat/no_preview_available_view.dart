import 'package:flutter/material.dart';

class NoPreviewAvailableView extends StatelessWidget {
  final VoidCallback? onRedeploy;
  final VoidCallback? onOpenCode;
  final bool isDeploying;

  const NoPreviewAvailableView({
    super.key,
    this.onRedeploy,
    this.onOpenCode,
    this.isDeploying = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.preview_outlined,
                  size: 34,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.72,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Preview Yet',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Deploy a fresh build or jump into code to keep working. Once the preview is ready it will appear here automatically.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.88,
                  ),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: isDeploying ? null : onRedeploy,
                    icon: isDeploying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.rocket_launch_outlined),
                    label: Text(isDeploying ? 'Deploying…' : 'Deploy Preview'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenCode,
                    icon: const Icon(Icons.code_rounded),
                    label: const Text('Open Code'),
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
