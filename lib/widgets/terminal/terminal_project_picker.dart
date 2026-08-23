import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/project.dart';

class TerminalProjectPicker extends StatelessWidget {
  final List<UserProject> projects;
  final String? selectedProjectId;
  final bool enabled;
  final ValueChanged<String?> onSelected;

  const TerminalProjectPicker({
    super.key,
    required this.projects,
    required this.selectedProjectId,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final selected = _selectedProject;
    return Semantics(
      button: true,
      label: context.tr('terminal_target_project', 'Terminal target'),
      child: OutlinedButton.icon(
        key: const ValueKey('terminal-project-picker'),
        onPressed: enabled ? () => _open(context) : null,
        icon: Icon(
          selected == null
              ? Icons.folder_open_outlined
              : Icons.folder_special_outlined,
          size: 19,
        ),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            selected?.projectName ??
                context.tr('terminal_target_workspace_root', 'Workspace root'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  UserProject? get _selectedProject {
    for (final project in projects) {
      if (project.id == selectedProjectId) return project;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _TerminalProjectDialog(
        projects: projects,
        selectedProjectId: selectedProjectId,
      ),
    );
    if (!context.mounted || result == null) return;
    onSelected(result.isEmpty ? null : result);
  }
}

class _TerminalProjectDialog extends StatefulWidget {
  final List<UserProject> projects;
  final String? selectedProjectId;

  const _TerminalProjectDialog({
    required this.projects,
    required this.selectedProjectId,
  });

  @override
  State<_TerminalProjectDialog> createState() => _TerminalProjectDialogState();
}

class _TerminalProjectDialogState extends State<_TerminalProjectDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.projects.where((project) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty || project.projectName.toLowerCase().contains(query);
    }).toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('terminal_target_select', 'Select target'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.tr(
                    'terminal_target_search',
                    'Search projects',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  _TargetTile(
                    icon: Icons.folder_open_outlined,
                    title: context.tr(
                      'terminal_target_workspace_root',
                      'Workspace root',
                    ),
                    selected: widget.selectedProjectId == null,
                    onTap: () => Navigator.of(context).pop(''),
                  ),
                  for (final project in filtered)
                    _TargetTile(
                      icon: Icons.folder_special_outlined,
                      title: project.projectName,
                      selected: widget.selectedProjectId == project.id,
                      onTap: () => Navigator.of(context).pop(project.id),
                    ),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.tr(
                          'terminal_target_no_projects',
                          'No matching projects',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _TargetTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 48,
      leading: Icon(icon),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selected ? const Icon(Icons.check_rounded) : null,
      selected: selected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}
