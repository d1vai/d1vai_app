import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/card.dart';
import 'api_keys_tab.dart';
import 'github_tab.dart';

class DeveloperSettingsTab extends StatefulWidget {
  final VoidCallback onShowEditorPreferences;

  const DeveloperSettingsTab({
    super.key,
    required this.onShowEditorPreferences,
  });

  @override
  State<DeveloperSettingsTab> createState() => _DeveloperSettingsTabState();
}

class _DeveloperSettingsTabState extends State<DeveloperSettingsTab> {
  _DeveloperSection? _section;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    return value == null || value == key ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    if (_section == _DeveloperSection.github) {
      return _DeveloperDetail(
        title: _t('github', 'GitHub'),
        onBack: () => setState(() => _section = null),
        child: const SettingsGithubTab(),
      );
    }
    if (_section == _DeveloperSection.apiKeys) {
      return _DeveloperDetail(
        title: _t('settings_api_key', 'API Keys'),
        onBack: () => setState(() => _section = null),
        child: const SettingsApiKeysTab(),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          _t('developer', 'Developer'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t(
            'developer_settings_subtitle',
            'Connections, keys, editor, and API diagnostics.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _DeveloperEntry(
          icon: Icons.account_tree_outlined,
          color: cs.primary,
          title: _t('github', 'GitHub'),
          subtitle: _t('github_integration', 'GitHub integration'),
          onTap: () => setState(() => _section = _DeveloperSection.github),
        ),
        _DeveloperEntry(
          icon: Icons.key_outlined,
          color: cs.tertiary,
          title: _t('settings_api_key', 'API Keys'),
          subtitle: _t(
            'api_keys_subtitle',
            'Create and revoke personal API keys',
          ),
          onTap: () => setState(() => _section = _DeveloperSection.apiKeys),
        ),
        _DeveloperEntry(
          icon: Icons.code_rounded,
          color: cs.secondary,
          title: _t('settings_editor_title', 'Code Editor'),
          subtitle: _t('settings_editor_entry_subtitle', 'Theme, font, wrap'),
          onTap: widget.onShowEditorPreferences,
        ),
        _DeveloperEntry(
          icon: Icons.settings_ethernet_rounded,
          color: cs.onSurfaceVariant,
          title: _t('api_settings', 'API Settings'),
          subtitle: _t(
            'developer_api_settings_subtitle',
            'Connection and runtime diagnostics',
          ),
          onTap: () => context.push('/settings/api'),
        ),
      ],
    );
  }
}

enum _DeveloperSection { github, apiKeys }

class _DeveloperEntry extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DeveloperEntry({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CustomCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _DeveloperDetail extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget child;

  const _DeveloperDetail({
    required this.title,
    required this.onBack,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
