import 'package:flutter/material.dart';

import '../../../models/env_var.dart';

class ProjectChatEnvTab extends StatelessWidget {
  final List<EnvVar> envVars;
  final bool isLoading;
  final ValueChanged<EnvVar> onAskAboutEnvVar;

  const ProjectChatEnvTab({
    super.key,
    required this.envVars,
    required this.isLoading,
    required this.onAskAboutEnvVar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (envVars.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Environment Variables',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add environment variables to your project',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: envVars.length,
      itemBuilder: (context, index) {
        final envVar = envVars[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.key,
                color: theme.colorScheme.onSecondaryContainer,
                size: 20,
              ),
            ),
            title: Text(envVar.key),
            subtitle: Text(
              (envVar.value == null || envVar.value!.isEmpty)
                  ? '(empty value)'
                  : '************',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => onAskAboutEnvVar(envVar),
            onLongPress: () => _showEnvVarValueDialog(context, envVar),
          ),
        );
      },
    );
  }

  void _showEnvVarValueDialog(BuildContext context, EnvVar envVar) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(envVar.key),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Value:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SelectableText(
              (envVar.value == null || envVar.value!.isEmpty)
                  ? '(empty value)'
                  : envVar.value!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
