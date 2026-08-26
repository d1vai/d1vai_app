import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../core/avatar_generator.dart';
import '../../providers/organization_provider.dart';
import '../adaptive_modal.dart';
import '../avatar_image.dart';
import '../snackbar_helper.dart';

String _workspaceText(BuildContext context, String key, String fallback) {
  final value = AppLocalizations.of(context)?.translate(key);
  return value == null || value == key ? fallback : value;
}

class WorkspaceSwitcher extends StatelessWidget {
  final bool expanded;
  final bool avatarOnly;
  final VoidCallback? onChanged;

  const WorkspaceSwitcher({
    super.key,
    this.expanded = false,
    this.avatarOnly = false,
    this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final provider = context.read<OrganizationProvider>();
    await provider.load();
    if (!context.mounted) return;
    await showAdaptiveModal<void>(
      context: context,
      builder: (_) => _WorkspacePicker(onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrganizationProvider>();
    final organization = provider.activeOrganization;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final switcher = Semantics(
      button: true,
      label: _workspaceText(context, 'organization_switch', 'Switch workspace'),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: avatarOnly
              ? const EdgeInsets.all(7)
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.66),
            ),
          ),
          child: Row(
            mainAxisSize: avatarOnly || !expanded
                ? MainAxisSize.min
                : MainAxisSize.max,
            children: [
              _WorkspaceAvatar(
                name: provider.workspaceName,
                picture:
                    organization?.picture ??
                    provider.context?.personal.picture ??
                    '',
                organization: organization != null,
                size: 28,
              ),
              if (!avatarOnly) ...[
                const SizedBox(width: 9),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.workspaceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (expanded)
                        Text(
                          organization == null
                              ? _workspaceText(
                                  context,
                                  'organization_personal',
                                  'Personal workspace',
                                )
                              : organization.role == 'owner'
                              ? _workspaceText(
                                  context,
                                  'organization_owner',
                                  'Owner',
                                )
                              : _workspaceText(
                                  context,
                                  'organization_member',
                                  'Member',
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return avatarOnly
        ? Tooltip(message: provider.workspaceName, child: switcher)
        : switcher;
  }
}

class _WorkspacePicker extends StatelessWidget {
  final VoidCallback? onChanged;

  const _WorkspacePicker({this.onChanged});

  Future<void> _select(BuildContext context, int? id) async {
    await context.read<OrganizationProvider>().select(id);
    onChanged?.call();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrganizationProvider>();
    final theme = Theme.of(context);
    final personal = provider.context?.personal;
    return AdaptiveModalContainer(
      maxWidth: 520,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _workspaceText(
                    context,
                    'organization_workspaces',
                    'Workspaces',
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (personal != null)
            _WorkspaceTile(
              name: personal.name,
              subtitle: _workspaceText(
                context,
                'organization_personal',
                'Personal workspace',
              ),
              picture: personal.picture,
              organization: false,
              selected: provider.activeOrganizationId == null,
              onTap: () => _select(context, null),
            ),
          for (final organization
              in provider.context?.organizations ?? const [])
            _WorkspaceTile(
              name: organization.name,
              subtitle:
                  '${organization.projectCount} ${_workspaceText(context, 'organization_projects', 'projects')} · ${organization.role == 'owner' ? _workspaceText(context, 'organization_owner', 'Owner') : _workspaceText(context, 'organization_member', 'Member')}',
              picture: organization.picture,
              organization: true,
              selected: provider.activeOrganizationId == organization.id,
              onTap: () => _select(context, organization.id),
              onManage: () {
                Navigator.of(context).pop();
                context.push('/organization/${organization.slug}');
              },
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              showAdaptiveModal<void>(
                context: context,
                builder: (_) => const _CreateOrganizationForm(),
              );
            },
            icon: const Icon(Icons.add_business_outlined),
            label: Text(
              _workspaceText(
                context,
                'organization_create',
                'Create organization',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String picture;
  final bool organization;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onManage;

  const _WorkspaceTile({
    required this.name,
    required this.subtitle,
    required this.picture,
    required this.organization,
    required this.selected,
    required this.onTap,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: selected
            ? scheme.primaryContainer.withValues(alpha: 0.62)
            : null,
        leading: _WorkspaceAvatar(
          name: name,
          picture: picture,
          organization: organization,
          size: 38,
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: onManage == null
            ? (selected ? const Icon(Icons.check_rounded) : null)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) const Icon(Icons.check_rounded, size: 20),
                  IconButton(
                    tooltip: _workspaceText(
                      context,
                      'organization_manage',
                      'Manage organization',
                    ),
                    onPressed: onManage,
                    icon: const Icon(Icons.settings_outlined, size: 20),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WorkspaceAvatar extends StatelessWidget {
  final String name;
  final String picture;
  final bool organization;
  final double size;

  const _WorkspaceAvatar({
    required this.name,
    required this.picture,
    required this.organization,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPicture = picture.trim().isNotEmpty;
    if (hasPicture) {
      return AvatarImage(
        imageUrl: picture,
        size: size,
        placeholderText: name,
        showBorder: true,
        borderWidth: 1,
        borderColor: scheme.outlineVariant.withValues(alpha: 0.66),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: organization
          ? scheme.secondaryContainer
          : scheme.primaryContainer,
      child: Icon(
        organization ? Icons.business_rounded : Icons.person_rounded,
        size: size * 0.52,
        color: organization
            ? scheme.onSecondaryContainer
            : scheme.onPrimaryContainer,
      ),
    );
  }
}

class _CreateOrganizationForm extends StatefulWidget {
  const _CreateOrganizationForm();

  @override
  State<_CreateOrganizationForm> createState() =>
      _CreateOrganizationFormState();
}

class _CreateOrganizationFormState extends State<_CreateOrganizationForm> {
  final _avatarGenerator = DeveloperAvatarGenerator();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _website = TextEditingController();
  final _description = TextEditingController();
  bool _slugEdited = false;
  bool _submitting = false;
  late String _picture = _generatePicture();

  String _generatePicture() => _avatarGenerator.generateAvatar(
    'organization-${DateTime.now().microsecondsSinceEpoch}',
    size: 160,
    consistent: false,
  );

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _website.dispose();
    _description.dispose();
    super.dispose();
  }

  String _slugify(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _submit() async {
    final slug = _slug.text.trim();
    if (_name.text.trim().isEmpty ||
        !RegExp(r'^[a-z0-9][a-z0-9-]{1,127}$').hasMatch(slug)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<OrganizationProvider>().create(
        name: _name.text,
        slug: slug,
        website: _website.text,
        description: _description.text,
        picture: _picture,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      SnackBarHelper.showSuccess(
        context,
        title: _workspaceText(
          context,
          'organization_created',
          'Organization created',
        ),
        message: _workspaceText(
          context,
          'organization_created_detail',
          'Your shared workspace is ready.',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: _workspaceText(
          context,
          'organization_create_failed',
          'Creation failed',
        ),
        message: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveModalContainer(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        shrinkWrap: true,
        children: [
          Text(
            _workspaceText(
              context,
              'organization_create',
              'Create organization',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _workspaceText(context, 'organization_name', 'Name'),
              prefixIcon: const Icon(Icons.business_outlined),
            ),
            onChanged: (value) {
              if (!_slugEdited) _slug.text = _slugify(value);
              setState(() {});
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _slug,
            decoration: InputDecoration(
              labelText: _workspaceText(
                context,
                'organization_slug',
                'Workspace URL',
              ),
              prefixText: 'd1v.ai/u/',
            ),
            onChanged: (_) {
              _slugEdited = true;
              setState(() {});
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _website,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: _workspaceText(
                context,
                'organization_website',
                'Website',
              ),
              prefixIcon: const Icon(Icons.language_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(radius: 30, backgroundImage: NetworkImage(_picture)),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _picture = _generatePicture()),
                icon: const Icon(Icons.casino_outlined),
                label: Text(
                  _workspaceText(
                    context,
                    'organization_random_avatar',
                    'Random logo',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _workspaceText(
                context,
                'organization_description',
                'Description',
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business_outlined),
                label: Text(
                  _workspaceText(
                    context,
                    'organization_create_action',
                    'Create',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
