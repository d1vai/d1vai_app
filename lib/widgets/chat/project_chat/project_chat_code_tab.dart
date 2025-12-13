import 'package:flutter/material.dart';

class ProjectChatCodeTab extends StatelessWidget {
  final ValueChanged<String> onAsk;

  const ProjectChatCodeTab({super.key, required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Files',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.folder, color: theme.colorScheme.secondary),
              title: const Text('src/'),
              subtitle: const Text('Source files'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => onAsk(
                'Can you explain the structure and contents of the src/ directory in my project?',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.folder, color: theme.colorScheme.secondary),
              title: const Text('public/'),
              subtitle: const Text('Static assets'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => onAsk(
                'Can you help me understand and optimize the files in the public/ directory?',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.description,
                color: theme.colorScheme.primary,
              ),
              title: const Text('README.md'),
              subtitle: const Text('Project documentation'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => onAsk(
                'Please review my README.md and suggest improvements to documentation and onboarding.',
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.settings, color: theme.colorScheme.tertiary),
              title: const Text('package.json'),
              subtitle: const Text('Dependencies'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => onAsk(
                'Can you review my package.json and suggest any improvements or additional dependencies?',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Click on any file or folder to ask AI for insights, explanations, or suggestions',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
