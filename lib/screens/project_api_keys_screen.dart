import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api_client.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';

class ProjectApiKeysScreen extends StatefulWidget {
  final String projectId;

  const ProjectApiKeysScreen({super.key, required this.projectId});

  @override
  State<ProjectApiKeysScreen> createState() => _ProjectApiKeysScreenState();
}

class _ProjectApiKeysScreenState extends State<ProjectApiKeysScreen> {
  final _service = D1vaiService();
  bool _loading = false;
  String? _token;
  String? _expiresAt;
  List<String> _scopes = const <String>[];

  int _ttlSeconds = 1800;
  final Set<String> _selectedScopes = <String>{'db:read', 'migrate'};

  Future<void> _issueToken() async {
    setState(() => _loading = true);
    try {
      final res = await _service.issueProjectToken(
        widget.projectId,
        scopes: _selectedScopes.toList()..sort(),
        ttlSeconds: _ttlSeconds,
      );
      final token = (res['project_token'] ?? res['token'] ?? '').toString();
      final expiresAt = (res['expires_at'] ?? '').toString();
      final scopesRaw = res['scopes'];
      final scopes = (scopesRaw is List)
          ? scopesRaw.map((e) => e.toString()).toList()
          : _selectedScopes.toList();

      if (!mounted) return;
      setState(() {
        _token = token;
        _expiresAt = expiresAt;
        _scopes = scopes;
      });
      SnackBarHelper.showSuccess(
        context,
        title: 'Token issued',
        message: 'Expires at $expiresAt',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(context, title: 'Failed', message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyToken() async {
    final token = (_token ?? '').trim();
    if (token.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Copied',
      message: 'Token copied to clipboard',
    );
  }

  Future<void> _shareToken() async {
    final token = (_token ?? '').trim();
    if (token.isEmpty) return;
    await Share.share(token, subject: 'Project token');
  }

  void _clearTokenFromScreen() {
    setState(() {
      _token = null;
      _expiresAt = null;
      _scopes = const <String>[];
    });
    SnackBarHelper.showInfo(
      context,
      title: 'Cleared',
      message: 'Token removed from screen (it will still expire on schedule)',
    );
  }

  String _ttlLabel(int seconds) {
    if (seconds <= 3600) return '${(seconds / 60).round()}m';
    return '${(seconds / 3600).round()}h';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = (_token ?? '').trim();

    final exampleUrl =
        '${ApiClient.baseUrl}/api/projects/${widget.projectId}/db/schema';
    final curl = token.isEmpty
        ? 'curl -H "Authorization: Bearer <token>" "$exampleUrl"'
        : 'curl -H "Authorization: Bearer $token" "$exampleUrl"';

    return Scaffold(
      appBar: AppBar(title: const Text('API Keys')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Issue a project token',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tokens are short-lived (TTL) and scoped. There is no server-side list yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ScopeChip(
                        label: 'db:read',
                        selected: _selectedScopes.contains('db:read'),
                        onTap: () {
                          setState(() {
                            if (_selectedScopes.contains('db:read')) {
                              _selectedScopes.remove('db:read');
                            } else {
                              _selectedScopes.add('db:read');
                            }
                          });
                        },
                      ),
                      _ScopeChip(
                        label: 'db:write',
                        selected: _selectedScopes.contains('db:write'),
                        onTap: () {
                          setState(() {
                            if (_selectedScopes.contains('db:write')) {
                              _selectedScopes.remove('db:write');
                            } else {
                              _selectedScopes.add('db:write');
                            }
                          });
                        },
                      ),
                      _ScopeChip(
                        label: 'migrate',
                        selected: _selectedScopes.contains('migrate'),
                        onTap: () {
                          setState(() {
                            if (_selectedScopes.contains('migrate')) {
                              _selectedScopes.remove('migrate');
                            } else {
                              _selectedScopes.add('migrate');
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final v in const <int>[
                        900,
                        1800,
                        3600,
                        6 * 3600,
                        24 * 3600,
                      ])
                        ChoiceChip(
                          label: Text(_ttlLabel(v)),
                          selected: _ttlSeconds == v,
                          onSelected: (_) => setState(() => _ttlSeconds = v),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _issueToken,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.key),
                      label: Text(_loading ? 'Issuing…' : 'Issue token'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current token',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (token.isEmpty)
                    Text(
                      'No token issued yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: SelectableText(
                        token,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if ((_expiresAt ?? '').trim().isNotEmpty)
                          _MetaTag(text: 'expires: ${_expiresAt!.trim()}'),
                        ..._scopes.map((s) => _MetaTag(text: s)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyToken,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareToken,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _clearTokenFromScreen,
                        icon: const Icon(Icons.visibility_off_outlined),
                        label: const Text('Remove from screen'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Example (curl)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: SelectableText(
                      curl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String text;

  const _MetaTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
