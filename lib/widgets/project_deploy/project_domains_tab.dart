import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth_expiry_bus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/project_custom_domain.dart';
import '../../services/d1vai_service.dart';
import '../../utils/error_utils.dart';
import '../card.dart';
import '../snackbar_helper.dart';

class ProjectDomainsTab extends StatefulWidget {
  final String projectId;
  final String? platformDomain;

  const ProjectDomainsTab({
    super.key,
    required this.projectId,
    this.platformDomain,
  });

  @override
  State<ProjectDomainsTab> createState() => _ProjectDomainsTabState();
}

class _ProjectDomainsTabState extends State<ProjectDomainsTab> {
  static const _pollInterval = Duration(seconds: 8);
  static const _maximumPollDuration = Duration(minutes: 5);

  final _service = D1vaiService();
  List<ProjectCustomDomain> _domains = const [];
  String? _platformDomain;
  bool _loading = true;
  bool _mutating = false;
  String? _error;
  Timer? _pollTimer;
  DateTime? _pollStartedAt;

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    return value == null || value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _platformDomain = widget.platformDomain;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant ProjectDomainsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _pollTimer?.cancel();
      _domains = const [];
      _platformDomain = widget.platformDomain;
      unawaited(_load(showLoading: true));
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _hasPendingDomains => _domains.any((domain) => domain.isPendingDns);

  Future<void> _load({
    bool showLoading = false,
    bool reportError = true,
  }) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _service.getProjectCustomDomains(widget.projectId);
      if (!mounted) return;
      setState(() {
        _domains = result.domains;
        _platformDomain = result.platformDomain ?? widget.platformDomain;
        _loading = false;
        _error = null;
      });
      _syncPolling();
    } catch (error) {
      if (!mounted) return;
      final message = humanizeError(error);
      if (isAuthExpiredText(message)) {
        AuthExpiryBus.trigger(
          endpoint: '/api/deployment/${widget.projectId}/domains',
        );
        return;
      }
      setState(() {
        _loading = false;
        _error = message;
      });
      if (reportError) {
        SnackBarHelper.showError(
          context,
          title: _t('failed_to_load', 'Failed to load'),
          message: message,
        );
      }
    }
  }

  void _syncPolling() {
    if (!_hasPendingDomains) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _pollStartedAt = null;
      return;
    }
    _pollStartedAt ??= DateTime.now();
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      final startedAt = _pollStartedAt;
      if (startedAt == null ||
          DateTime.now().difference(startedAt) >= _maximumPollDuration) {
        _pollTimer?.cancel();
        _pollTimer = null;
        return;
      }
      unawaited(_verifyPendingDomains());
    });
  }

  Future<void> _verifyPendingDomains() async {
    if (_mutating || !_hasPendingDomains) return;
    try {
      await Future.wait(
        _domains
            .where((domain) => domain.isPendingDns)
            .map(
              (domain) => _service.verifyProjectCustomDomain(
                widget.projectId,
                domain.id,
              ),
            ),
      );
      await _load(reportError: false);
    } catch (_) {
      // DNS propagation can be incomplete. The next polling attempt retries.
    }
  }

  Future<void> _copy(String value, String label) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    SnackBarHelper.showSuccess(
      context,
      title: _t('copied', 'Copied'),
      message: '$label ${_t('project_domains_copied', 'copied')}',
    );
  }

  Future<void> _showAddDomainDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('project_domains_add_title', 'Add domain')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: _t('project_domains_add_hint', 'app.example.com'),
            helperText: _t(
              'project_domains_add_helper',
              'Enter a domain without https:// or a path.',
            ),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_t('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(_t('project_domains_add', 'Add domain')),
          ),
        ],
      ),
    );
    controller.dispose();
    final domain = (result ?? '').trim();
    if (domain.isEmpty) return;

    setState(() => _mutating = true);
    try {
      final added = await _service.addProjectCustomDomain(
        widget.projectId,
        domain: domain,
      );
      if (!mounted) return;
      setState(() {
        _domains = [..._domains.where((item) => item.id != added.id), added];
      });
      _syncPolling();
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_domains_add_failed', 'Could not add domain'),
        message: humanizeError(error),
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _verify(ProjectCustomDomain domain) async {
    setState(() => _mutating = true);
    try {
      final updated = await _service.verifyProjectCustomDomain(
        widget.projectId,
        domain.id,
      );
      if (!mounted) return;
      setState(() {
        _domains = _domains
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      });
      _syncPolling();
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_domains_verify_failed', 'Verification failed'),
        message: humanizeError(error),
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _confirmDelete(ProjectCustomDomain domain) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('project_domains_delete_title', 'Remove domain?')),
        content: Text(
          _t(
            'project_domains_delete_message',
            'This disconnects {domain} from this project.',
          ).replaceAll('{domain}', domain.domain),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_t('delete', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _mutating = true);
    try {
      await _service.deleteProjectCustomDomain(widget.projectId, domain.id);
      if (!mounted) return;
      setState(() {
        _domains = _domains
            .where((item) => item.id != domain.id)
            .toList(growable: false);
      });
      _syncPolling();
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _t('project_domains_delete_failed', 'Could not remove domain'),
        message: humanizeError(error),
      );
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.language_rounded,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('project_domains_title', 'Custom domains'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _t(
                        'project_domains_description',
                        'Connect a domain and follow the DNS records provided by Vercel.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _t('project_domains_refresh', 'Refresh'),
                onPressed: _mutating ? null : () => _load(showLoading: true),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_platformDomain?.trim().isNotEmpty == true) ...[
          _PlatformDomainCard(
            label: _t('project_domains_platform_domain', 'Platform domain'),
            domain: _platformDomain!.trim(),
            copyLabel: _t('project_domains_domain', 'Domain'),
            onCopy: _copy,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                _t('project_domains_your_domains', 'Your domains'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _mutating ? null : _showAddDomainDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(_t('project_domains_add', 'Add domain')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_error != null)
          _ErrorCard(
            message: _error!,
            retryLabel: _t('project_domains_retry', 'Retry'),
            onRetry: () => _load(showLoading: true),
          )
        else if (_domains.isEmpty)
          _EmptyDomainsCard(
            title: _t('project_domains_empty_title', 'No custom domains yet'),
            description: _t(
              'project_domains_empty_description',
              'Add a domain to connect it to this production project.',
            ),
          )
        else
          ..._domains.map(
            (domain) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DomainCard(
                domain: domain,
                mutating: _mutating,
                t: _t,
                onCopy: _copy,
                onVerify: () => _verify(domain),
                onDelete: () => _confirmDelete(domain),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlatformDomainCard extends StatelessWidget {
  final String label;
  final String domain;
  final String copyLabel;
  final Future<void> Function(String value, String label) onCopy;

  const _PlatformDomainCard({
    required this.label,
    required this.domain,
    required this.copyLabel,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return CustomCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.public_outlined, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  domain,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: copyLabel,
            onPressed: () => onCopy(domain, copyLabel),
            icon: const Icon(Icons.copy_outlined, size: 19),
          ),
        ],
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  final ProjectCustomDomain domain;
  final bool mutating;
  final String Function(String key, String fallback) t;
  final Future<void> Function(String value, String label) onCopy;
  final VoidCallback onVerify;
  final VoidCallback onDelete;

  const _DomainCard({
    required this.domain,
    required this.mutating,
    required this.t,
    required this.onCopy,
    required this.onVerify,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final verified = domain.isVerified;
    final statusColor = verified ? cs.primary : cs.tertiary;
    final statusLabel = verified
        ? t('project_domains_verified', 'Verified')
        : t('project_domains_pending_dns', 'DNS setup required');
    return CustomCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.pending_outlined,
                color: statusColor,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  domain.domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: t('project_domains_domain', 'Domain'),
                onPressed: () => onCopy(
                  domain.domain,
                  t('project_domains_domain', 'Domain'),
                ),
                icon: const Icon(Icons.copy_outlined, size: 19),
              ),
              IconButton(
                tooltip: t('delete', 'Delete'),
                onPressed: mutating ? null : onDelete,
                color: cs.error,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatusPill(label: statusLabel, color: statusColor),
          if (!verified) ...[
            const SizedBox(height: 12),
            Text(
              t('project_domains_dns_records', 'DNS records'),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            ...domain.verification.map(
              (record) => _DnsRecordRow(record: record, t: t, onCopy: onCopy),
            ),
            if (domain.errorMessage?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                domain.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: mutating ? null : onVerify,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: Text(t('project_domains_verify', 'Verify DNS')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DnsRecordRow extends StatelessWidget {
  final ProjectCustomDomainDnsRecord record;
  final String Function(String key, String fallback) t;
  final Future<void> Function(String value, String label) onCopy;

  const _DnsRecordRow({
    required this.record,
    required this.t,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 9, 7, 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DnsValue(
            label: t('project_domains_dns_type', 'Type'),
            value: record.type,
            onCopy: null,
          ),
          const SizedBox(height: 6),
          _DnsValue(
            label: t('project_domains_dns_key', 'Key'),
            value: record.domain,
            onCopy: () =>
                onCopy(record.domain, t('project_domains_dns_key', 'Key')),
          ),
          const SizedBox(height: 6),
          _DnsValue(
            label: t('project_domains_dns_value', 'Value'),
            value: record.value,
            onCopy: () =>
                onCopy(record.value, t('project_domains_dns_value', 'Value')),
          ),
        ],
      ),
    );
  }
}

class _DnsValue extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _DnsValue({required this.label, required this.value, this.onCopy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
        if (onCopy != null)
          IconButton(
            tooltip: label,
            visualDensity: VisualDensity.compact,
            onPressed: onCopy,
            icon: const Icon(Icons.copy_outlined, size: 17),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomCard(
      borderColor: cs.error.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

class _EmptyDomainsCard extends StatelessWidget {
  final String title;
  final String description;

  const _EmptyDomainsCard({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.language_outlined, size: 32, color: cs.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
