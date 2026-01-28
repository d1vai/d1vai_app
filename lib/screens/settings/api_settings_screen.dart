import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../services/workspace_service.dart';
import '../../widgets/snackbar_helper.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final TextEditingController _controller = TextEditingController();
  final WorkspaceService _workspaceService = WorkspaceService();

  bool _saving = false;
  bool _testing = false;
  String? _validationError;
  WorkspaceStateInfo? _status;

  @override
  void initState() {
    super.initState();
    () async {
      await ApiClient.ensureInitialized();
      if (!mounted) return;
      setState(() {
        _controller.text = ApiClient.runtimeBaseUrl ?? '';
      });
    }();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validateBaseUrl(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    if (uri == null) return 'Invalid URL';
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) {
      return 'URL must start with http:// or https://';
    }
    if (uri.host.trim().isEmpty) return 'Missing host';
    // We expect base like https://api.d1v.ai (no /api path).
    final path = uri.path.trim();
    if (path.isNotEmpty && path != '/') {
      return 'Base URL should not include a path (remove "$path")';
    }
    return null;
  }

  String _normalizeBaseUrl(String raw) {
    final v = raw.trim();
    final uri = Uri.parse(v);
    final normalized = uri.replace(path: '', query: '', fragment: '').toString();
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  Future<void> _save() async {
    if (_saving) return;
    final err = _validateBaseUrl(_controller.text);
    setState(() {
      _validationError = err;
    });
    if (err != null) return;

    setState(() {
      _saving = true;
    });
    try {
      final raw = _controller.text.trim();
      await ApiClient.setRuntimeBaseUrlOverride(
        raw.isEmpty ? null : _normalizeBaseUrl(raw),
      );
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Saved',
        message: 'API base URL updated',
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to save API base URL',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _reset() async {
    if (_saving) return;
    setState(() {
      _controller.text = '';
      _validationError = null;
      _status = null;
    });
    await _save();
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _status = null;
    });
    try {
      final st = await _workspaceService.getWorkspaceStatus(bypassCache: true);
      if (!mounted) return;
      setState(() {
        _status = st;
      });
      SnackBarHelper.showSuccess(
        context,
        title: 'Connected',
        message: 'Workspace status: ${st.status ?? 'unknown'}',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Connection failed',
        message: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
    }
  }

  Map<String, dynamic>? _decodeJwtClaims(String token) {
    final t = token.trim();
    final parts = t.split('.');
    if (parts.length < 2) return null;
    try {
      final payload = base64Url.normalize(parts[1]);
      final jsonStr = utf8.decode(base64Url.decode(payload));
      final decoded = jsonDecode(jsonStr);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _copyDiagnostics() async {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final platform =
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim();
    final target = defaultTargetPlatform.name;

    final prefs = await SharedPreferences.getInstance();
    final token = (prefs.getString('auth_token') ?? '').trim();
    final tokenSuffix = token.isEmpty
        ? ''
        : (token.length <= 6 ? token : token.substring(token.length - 6));
    final claims = token.isEmpty ? null : _decodeJwtClaims(token);

    String? expIso;
    final exp = claims?['exp'];
    if (exp is num) {
      expIso = DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      ).toIso8601String();
    }

    final text = [
      'effective_base_url=${ApiClient.baseUrl}',
      'env_base_url=${ApiClient.envBaseUrl}',
      'override_base_url=${ApiClient.runtimeBaseUrl ?? ''}',
      'auth_token_present=${token.isNotEmpty}',
      if (token.isNotEmpty) 'auth_token_len=${token.length} suffix=$tokenSuffix',
      if (claims != null && claims['type'] != null)
        "jwt_type=${claims['type']}",
      if (claims != null && claims['sub'] != null) "jwt_sub=${claims['sub']}",
      if (expIso != null) 'jwt_exp_utc=$expIso',
    if (_status != null)
        'workspace_status=${_status!.status ?? ''} ip=${_status!.ip ?? ''} port=${_status!.port ?? ''}',
      'locale=$localeTag',
      'platform=$platform',
      'target_platform=$target',
    ].join('\n');

    // Attach the last recorded API error if available.
    final lastErrRaw = prefs.getString('api_last_error');
    final lastErrLine = (lastErrRaw == null || lastErrRaw.trim().isEmpty)
        ? null
        : () {
            try {
              final decoded = jsonDecode(lastErrRaw);
              if (decoded is Map) {
                final m = Map<String, dynamic>.from(decoded);
                final at = (m['at'] ?? '').toString();
                final ep = (m['endpoint'] ?? '').toString();
                final st = m['status'];
                final msg = (m['message'] ?? '').toString();
                return [
                  'last_api_error.at=$at',
                  'last_api_error.endpoint=$ep',
                  if (st != null) 'last_api_error.status=$st',
                  if (msg.trim().isNotEmpty) 'last_api_error.message=$msg',
                ].join('\n');
              }
            } catch (_) {}
            return 'last_api_error.raw=$lastErrRaw';
          }();

    final fullText =
        lastErrLine == null ? text : '$text\n$lastErrLine';

    await Clipboard.setData(ClipboardData(text: fullText));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: 'Copied',
      message: 'Diagnostics copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _KeyValueRow(label: 'Effective', value: ApiClient.baseUrl),
                  const SizedBox(height: 6),
                  _KeyValueRow(label: 'Build-time', value: ApiClient.envBaseUrl),
                  const SizedBox(height: 6),
                  _KeyValueRow(
                    label: 'Override',
                    value: ApiClient.runtimeBaseUrl?.trim().isNotEmpty == true
                        ? ApiClient.runtimeBaseUrl!
                        : '—',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Use this if d1vai_app is pointing to a different backend than d1vai web.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Override API base URL',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'e.g. http://localhost:8999',
                      helperText: 'Leave empty to use build-time base URL.',
                      errorText: _validationError,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (v) {
                      setState(() {
                        _validationError = _validateBaseUrl(v);
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _reset,
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: const Text('Test connection'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyDiagnostics,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy diagnostics'),
                        ),
                      ),
                    ],
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Text(
                        'workspace.status=${_status!.status ?? '—'}\n'
                        'ip=${_status!.ip ?? '—'}\n'
                        'port=${_status!.port?.toString() ?? '—'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
