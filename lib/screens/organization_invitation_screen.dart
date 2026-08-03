import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/organization.dart';
import '../providers/auth_provider.dart';
import '../providers/organization_provider.dart';
import '../services/organization_service.dart';

OrganizationSummary? _findInvitationOrganization(
  Iterable<OrganizationSummary> organizations,
  String? slug,
) {
  for (final organization in organizations) {
    if (organization.slug == slug) return organization;
  }
  return null;
}

class OrganizationInvitationScreen extends StatefulWidget {
  final String token;
  final OrganizationService? service;

  const OrganizationInvitationScreen({
    super.key,
    required this.token,
    this.service,
  });

  @override
  State<OrganizationInvitationScreen> createState() =>
      _OrganizationInvitationScreenState();
}

class _OrganizationInvitationScreenState
    extends State<OrganizationInvitationScreen> {
  late final OrganizationService _service;
  OrganizationInvitationPreview? _preview;
  String? _error;
  bool _loading = true;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OrganizationService();
    _load();
  }

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    return value == null || value == key ? fallback : value;
  }

  Future<void> _load() async {
    try {
      final preview = await _service.previewInvitation(widget.token);
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    if (!context.read<AuthProvider>().isAuthenticated) {
      final destination = Uri.encodeQueryComponent(
        '/organization-invite/${widget.token}',
      );
      context.go('/login?redirect=$destination');
      return;
    }
    setState(() => _accepting = true);
    final organizationProvider = context.read<OrganizationProvider>();
    try {
      await _service.acceptInvitation(widget.token);
      await organizationProvider.load(force: true);
      if (!mounted) return;
      final organization = _findInvitationOrganization(
        organizationProvider.context?.organizations ?? const [],
        _preview?.slug,
      );
      if (organization != null) {
        await organizationProvider.select(organization.id);
      }
      if (mounted) context.go('/dashboard');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  if (_loading)
                    const CircularProgressIndicator()
                  else if (preview == null)
                    _InvitationState(
                      icon: Icons.link_off,
                      title: _t(
                        'organization_invitation_unavailable',
                        'Invitation unavailable',
                      ),
                      detail:
                          _error ??
                          _t(
                            'organization_invitation_not_found',
                            'This invitation cannot be found.',
                          ),
                    )
                  else ...[
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: scheme.primaryContainer,
                      backgroundImage: preview.picture.isEmpty
                          ? null
                          : NetworkImage(preview.picture),
                      child: preview.picture.isEmpty
                          ? const Icon(Icons.business_rounded, size: 34)
                          : null,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      preview.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_t('organization_invitation_for', 'Invitation for')} ${preview.emailHint}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    if (preview.status == 'pending')
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _accepting ? null : _accept,
                          icon: _accepting
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.group_add_outlined),
                          label: Text(
                            context.watch<AuthProvider>().isAuthenticated
                                ? _t('organization_join', 'Join organization')
                                : _t(
                                    'organization_sign_in_to_continue',
                                    'Sign in to continue',
                                  ),
                          ),
                        ),
                      )
                    else
                      _InvitationState(
                        icon: preview.status == 'revoked'
                            ? Icons.block_outlined
                            : Icons.schedule_outlined,
                        title: preview.status == 'revoked'
                            ? _t(
                                'organization_invitation_revoked',
                                'Invitation revoked',
                              )
                            : _t(
                                'organization_invitation_expired',
                                'Invitation expired',
                              ),
                        detail: _t(
                          'organization_invitation_renew',
                          'Ask an organization owner to send a new invitation.',
                        ),
                      ),
                    if (_error != null && preview.status == 'pending') ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InvitationState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _InvitationState({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 38),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(detail, textAlign: TextAlign.center),
      ],
    );
  }
}
