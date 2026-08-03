import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../core/avatar_generator.dart';
import '../models/organization.dart';
import '../models/project.dart';
import '../providers/organization_provider.dart';
import '../providers/project_provider.dart';
import '../services/organization_service.dart';
import '../utils/desktop_layout.dart';
import '../widgets/d1v_app_bar.dart';
import '../widgets/snackbar_helper.dart';

OrganizationSummary? _findOrganizationBySlug(
  Iterable<OrganizationSummary> organizations,
  String slug,
) {
  for (final organization in organizations) {
    if (organization.slug == slug) return organization;
  }
  return null;
}

String _organizationText(BuildContext context, String key, String fallback) {
  final value = AppLocalizations.of(context)?.translate(key);
  return value == null || value == key ? fallback : value;
}

class OrganizationScreen extends StatefulWidget {
  final String slug;
  final OrganizationService? service;

  const OrganizationScreen({super.key, required this.slug, this.service});

  @override
  State<OrganizationScreen> createState() => _OrganizationScreenState();
}

class _OrganizationScreenState extends State<OrganizationScreen> {
  late final OrganizationService _service;
  final _name = TextEditingController();
  final _website = TextEditingController();
  final _description = TextEditingController();
  final _inviteEmail = TextEditingController();
  final _avatarGenerator = DeveloperAvatarGenerator();
  bool _loading = true;
  bool _saving = false;
  bool _inviting = false;
  String? _error;
  OrganizationSummary? _organization;
  OrganizationWalletInfo? _wallet;
  List<OrganizationMemberInfo> _members = const [];
  List<OrganizationInvitationInfo> _invitations = const [];
  String _picture = '';

  String _t(String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    return value == null || value == key ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? OrganizationService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _website.dispose();
    _description.dispose();
    _inviteEmail.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = context.read<OrganizationProvider>();
      await provider.load(force: true);
      final organization = _findOrganizationBySlug(
        provider.context?.organizations ?? const [],
        widget.slug,
      );
      if (organization == null) {
        throw Exception(
          _t('organization_access_denied', 'Organization access denied'),
        );
      }
      final profile = await _service.getOrganization(widget.slug);
      final results = await Future.wait<dynamic>([
        _service.getMembers(widget.slug),
        _service.getWallet(widget.slug),
        if (organization.canManage) _service.getInvitations(widget.slug),
      ]);
      if (!mounted) return;
      _name.text = profile['name']?.toString() ?? organization.name;
      _website.text = profile['website']?.toString() ?? '';
      _description.text = profile['description']?.toString() ?? '';
      _picture = profile['picture']?.toString() ?? organization.picture;
      setState(() {
        _organization = organization;
        _members = results[0] as List<OrganizationMemberInfo>;
        _wallet = results[1] as OrganizationWalletInfo;
        _invitations = organization.canManage
            ? results[2] as List<OrganizationInvitationInfo>
            : const [];
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final organizationProvider = context.read<OrganizationProvider>();
    try {
      await _service.updateOrganization(widget.slug, {
        'name': _name.text.trim(),
        'website': _website.text.trim().isEmpty ? null : _website.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'picture': _picture.isEmpty ? null : _picture,
      });
      await organizationProvider.load(force: true);
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('organization_saved', 'Organization updated'),
        message: _t(
          'organization_saved_detail',
          'Public profile changes are live.',
        ),
      );
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t('organization_save_failed', 'Update failed'),
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _invite() async {
    final email = _inviteEmail.text.trim();
    if (email.isEmpty) return;
    setState(() => _inviting = true);
    try {
      await _service.invite(widget.slug, email);
      _inviteEmail.clear();
      final invitations = await _service.getInvitations(widget.slug);
      if (!mounted) return;
      setState(() => _invitations = invitations);
      SnackBarHelper.showSuccess(
        context,
        title: _t('organization_invite_sent', 'Invitation sent'),
        message: email,
      );
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t('organization_invite_failed', 'Invitation failed'),
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _revoke(OrganizationInvitationInfo invitation) async {
    final confirmed = await _confirm(
      title: _t('organization_revoke_invite', 'Revoke invitation?'),
      detail: invitation.email,
      action: _t('organization_revoke', 'Revoke'),
      destructive: true,
    );
    if (!confirmed) return;
    await _service.revokeInvitation(widget.slug, invitation.id);
    final invitations = await _service.getInvitations(widget.slug);
    if (mounted) setState(() => _invitations = invitations);
  }

  Future<void> _resend(OrganizationInvitationInfo invitation) async {
    try {
      await _service.resendInvitation(widget.slug, invitation.id);
      final invitations = await _service.getInvitations(widget.slug);
      if (!mounted) return;
      setState(() => _invitations = invitations);
      SnackBarHelper.showSuccess(
        context,
        title: _t('organization_invite_sent', 'Invitation sent'),
        message: invitation.email,
      );
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t('organization_invite_failed', 'Invitation failed'),
          message: error.toString(),
        );
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String detail,
    required String action,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _changeMember(
    OrganizationMemberInfo member,
    String action,
  ) async {
    try {
      if (action == 'remove') {
        final confirmed = await _confirm(
          title: _t('organization_remove_member', 'Remove member?'),
          detail: _t(
            'organization_remove_member_detail',
            'This user will immediately lose access to shared projects.',
          ),
          action: _t('organization_remove', 'Remove'),
          destructive: true,
        );
        if (!confirmed) return;
        await _service.removeMember(widget.slug, member.id);
      } else {
        await _service.updateMemberRole(widget.slug, member.id, action);
      }
      final members = await _service.getMembers(widget.slug);
      if (mounted) setState(() => _members = members);
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t('organization_member_update_failed', 'Update failed'),
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _fundWallet() async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('organization_fund', 'Transfer balance')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: r'$ ',
                labelText: _t('organization_amount', 'Amount'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t(
                'organization_fund_warning',
                'This transfer cannot be reversed. Confirm the amount before continuing.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: Text(_t('organization_confirm_transfer', 'Transfer')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || amount <= 0 || !mounted) return;
    try {
      await _service.fundWallet(widget.slug, amount);
      final wallet = await _service.getWallet(widget.slug);
      if (!mounted) return;
      setState(() => _wallet = wallet);
      SnackBarHelper.showSuccess(
        context,
        title: _t('organization_fund_success', 'Balance transferred'),
        message: '\$${amount.toStringAsFixed(2)}',
      );
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t('organization_fund_failed', 'Transfer failed'),
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _transferProject() async {
    List<UserProject> projects;
    try {
      projects = await _service.getPersonalProjects();
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t(
            'organization_projects_load_failed',
            'Unable to load projects',
          ),
          message: error.toString(),
        );
      }
      return;
    }
    if (!mounted) return;
    if (projects.isEmpty) {
      SnackBarHelper.showInfo(
        context,
        title: _t('organization_no_personal_projects', 'No personal projects'),
        message: _t(
          'organization_no_personal_projects_detail',
          'Create a personal project before transferring it.',
        ),
      );
      return;
    }
    final projectId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('organization_transfer_project', 'Transfer a project')),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                _t(
                  'organization_transfer_project_detail',
                  'The project, integrations, repository access, and future billing will move to this organization.',
                ),
              ),
              const SizedBox(height: 12),
              for (final project in projects)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(project.emoji ?? '·'),
                  title: Text(
                    project.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.arrow_forward_rounded),
                  onTap: () => Navigator.pop(context, project.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
    if (projectId == null || !mounted) return;
    final organizationProvider = context.read<OrganizationProvider>();
    final projectProvider = context.read<ProjectProvider>();
    try {
      await _service.transferProject(widget.slug, projectId);
      await organizationProvider.load(force: true);
      final activeId = organizationProvider.activeOrganizationId;
      await projectProvider.setOrganization(activeId);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: _t('organization_project_transferred', 'Project transferred'),
        message: _t(
          'organization_project_transferred_detail',
          'The project is now available in this organization workspace.',
        ),
      );
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t('organization_project_transfer_failed', 'Transfer failed'),
          message: error.toString(),
        );
      }
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('organization_leave', 'Leave organization?')),
        content: Text(
          _t(
            'organization_leave_detail',
            'You will lose access to shared projects and the organization workspace.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('organization_leave_action', 'Leave')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<OrganizationProvider>().leaveActive();
      if (mounted) context.go('/dashboard');
    } catch (error) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: _t('organization_leave_failed', 'Unable to leave'),
          message: error.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final organization = _organization;
    return Scaffold(
      appBar: D1VSimpleAppBar(
        enableBreathing: false,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          organization?.name ?? _t('organization_manage', 'Organization'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(
              context,
            ).refreshIndicatorSemanticLabel,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, retry: _load)
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final organization = _organization!;
    final desktop = isDesktopLayout(context);
    final scheme = Theme.of(context).colorScheme;
    final content = <Widget>[
      _WorkspaceOverview(
        organization: organization,
        picture: _picture,
        wallet: _wallet,
        memberCount: _members.length,
      ),
      if (organization.canManage) ...[
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _fundWallet,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Text(_t('organization_fund', 'Transfer balance')),
            ),
            OutlinedButton.icon(
              onPressed: _transferProject,
              icon: const Icon(Icons.drive_file_move_outline),
              label: Text(
                _t('organization_transfer_project', 'Transfer a project'),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 28),
      _SectionTitle(
        icon: Icons.badge_outlined,
        title: _t('organization_profile', 'Organization profile'),
        subtitle: _t(
          'organization_profile_detail',
          'Public identity shown on your organization page.',
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: _picture.isEmpty ? null : NetworkImage(_picture),
            child: _picture.isEmpty
                ? const Icon(Icons.business_rounded, size: 28)
                : null,
          ),
          if (organization.canManage) ...[
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(
                      () => _picture = _avatarGenerator.generateAvatar(
                        'organization-${DateTime.now().microsecondsSinceEpoch}',
                        size: 160,
                        consistent: false,
                      ),
                    ),
              icon: const Icon(Icons.casino_outlined),
              label: Text(_t('organization_random_avatar', 'Random logo')),
            ),
          ],
        ],
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _name,
        enabled: organization.canManage,
        decoration: InputDecoration(labelText: _t('organization_name', 'Name')),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _website,
        enabled: organization.canManage,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(
          labelText: _t('organization_website', 'Website'),
          prefixIcon: const Icon(Icons.language_outlined),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _description,
        enabled: organization.canManage,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: _t('organization_description', 'Description'),
          alignLabelWithHint: true,
        ),
      ),
      if (organization.canManage) ...[
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_t('organization_save', 'Save changes')),
          ),
        ),
      ],
      const SizedBox(height: 30),
      _SectionTitle(
        icon: Icons.group_outlined,
        title: _t('organization_members', 'Members'),
        subtitle: _t(
          'organization_members_detail',
          'Everyone here can collaborate on organization projects.',
        ),
      ),
      const SizedBox(height: 10),
      for (final member in _members)
        _MemberRow(
          member: member,
          canManage: organization.canManage,
          onAction: _changeMember,
        ),
      if (organization.canManage) ...[
        const SizedBox(height: 30),
        _SectionTitle(
          icon: Icons.person_add_alt_1_outlined,
          title: _t('organization_invite', 'Invite members'),
          subtitle: _t(
            'organization_invite_detail',
            'Invite by email. Links expire after seven days.',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _inviteEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'member@example.com',
                  prefixIcon: const Icon(Icons.mail_outline),
                ),
                onSubmitted: (_) => _inviting ? null : _invite(),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: _t('organization_send_invite', 'Send invitation'),
              onPressed: _inviting ? null : _invite,
              icon: _inviting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final invitation in _invitations)
          _InvitationRow(
            invitation: invitation,
            onResend: _resend,
            onRevoke: _revoke,
          ),
      ] else ...[
        const SizedBox(height: 30),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _leave,
          icon: const Icon(Icons.logout),
          label: Text(_t('organization_leave_action', 'Leave organization')),
        ),
      ],
      const SizedBox(height: 48),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 40 : 18,
          vertical: desktop ? 30 : 20,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceOverview extends StatelessWidget {
  final OrganizationSummary organization;
  final String picture;
  final OrganizationWalletInfo? wallet;
  final int memberCount;

  const _WorkspaceOverview({
    required this.organization,
    required this.picture,
    required this.wallet,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            radius: 27,
            backgroundImage: picture.isEmpty ? null : NetworkImage(picture),
            child: picture.isEmpty ? const Icon(Icons.business_rounded) : null,
          ),
          _Metric(
            label: _organizationText(context, 'organization_role', 'Role'),
            value: organization.role == 'owner'
                ? _organizationText(context, 'organization_owner', 'Owner')
                : _organizationText(context, 'organization_member', 'Member'),
          ),
          _Metric(
            label: _organizationText(
              context,
              'organization_projects_label',
              'Projects',
            ),
            value: '${organization.projectCount}',
          ),
          _Metric(
            label: _organizationText(
              context,
              'organization_members',
              'Members',
            ),
            value: '$memberCount',
          ),
          _Metric(
            label: _organizationText(
              context,
              'organization_shared_balance',
              'Shared balance',
            ),
            value: '\$${(wallet?.totalBalance ?? 0).toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final OrganizationMemberInfo member;
  final bool canManage;
  final void Function(OrganizationMemberInfo member, String action) onAction;

  const _MemberRow({
    required this.member,
    required this.canManage,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: member.picture.isEmpty
            ? null
            : NetworkImage(member.picture),
        child: member.picture.isEmpty
            ? Text(member.email.substring(0, 1).toUpperCase())
            : null,
      ),
      title: Text(member.email, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        member.role == 'owner'
            ? _organizationText(context, 'organization_owner', 'Owner')
            : _organizationText(context, 'organization_member', 'Member'),
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: _organizationText(
                context,
                'organization_member_actions',
                'Member actions',
              ),
              onSelected: (action) => onAction(member, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: member.role == 'owner' ? 'member' : 'owner',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      member.role == 'owner'
                          ? Icons.person_outline
                          : Icons.verified_user_outlined,
                    ),
                    title: Text(
                      member.role == 'owner'
                          ? _organizationText(
                              context,
                              'organization_make_member',
                              'Make member',
                            )
                          : _organizationText(
                              context,
                              'organization_make_owner',
                              'Make owner',
                            ),
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.person_remove_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      _organizationText(
                        context,
                        'organization_remove_member',
                        'Remove member',
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Icon(
              member.role == 'owner'
                  ? Icons.verified_user_outlined
                  : Icons.person_outline,
              size: 20,
            ),
    );
  }
}

class _InvitationRow extends StatelessWidget {
  final OrganizationInvitationInfo invitation;
  final ValueChanged<OrganizationInvitationInfo> onResend;
  final ValueChanged<OrganizationInvitationInfo> onRevoke;

  const _InvitationRow({
    required this.invitation,
    required this.onResend,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final pending = invitation.status == 'pending';
    final status = _organizationText(
      context,
      'organization_status_${invitation.status}',
      invitation.status,
    );
    final expires = MaterialLocalizations.of(
      context,
    ).formatShortDate(invitation.expiresAt.toLocal());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.mail_outline, size: 20)),
      title: Text(
        invitation.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('$status · $expires'),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: _organizationText(
              context,
              'organization_resend_invite',
              'Resend invitation',
            ),
            onPressed: () => onResend(invitation),
            icon: const Icon(Icons.refresh),
          ),
          if (pending)
            IconButton(
              tooltip: _organizationText(
                context,
                'organization_revoke_invite',
                'Revoke invitation',
              ),
              onPressed: () => onRevoke(invitation),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback retry;

  const _ErrorView({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: Text(
                _organizationText(context, 'organization_retry', 'Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
