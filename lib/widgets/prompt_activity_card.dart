import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/project.dart';
import '../models/prompt_activity.dart';
import '../providers/project_provider.dart';
import '../services/d1vai_service.dart';
import 'card.dart';
import 'compact_selector.dart';
import 'prompt_activity_heatmap.dart';
import 'skeletons/prompt_activity_skeleton.dart';
import 'snackbar_helper.dart';

/// Prompt activity for the current account, including an optional project scope.
class PromptActivityCard extends StatefulWidget {
  const PromptActivityCard({super.key});

  @override
  State<PromptActivityCard> createState() => _PromptActivityCardState();
}

class _PromptActivityCardState extends State<PromptActivityCard> {
  static const _allProjectsOptionValue = '__all_projects__';
  static const _activityDays = 161;

  final D1vaiService _service = D1vaiService();
  late Future<PromptDailyActivity> _activityFuture;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _activityFuture = _fetchActivity();
  }

  Future<PromptDailyActivity> _fetchActivity() => _service
      .getPromptDailyActivity(days: _activityDays, projectId: _projectId);

  void _reload() {
    setState(() => _activityFuture = _fetchActivity());
  }

  String _t(BuildContext context, String key, String fallback) {
    final value = AppLocalizations.of(context)?.translate(key);
    return value == null || value == key ? fallback : value;
  }

  String _projectDisplayName(UserProject project) {
    final name = project.projectName.trim();
    return name.isEmpty ? project.id : name;
  }

  Widget _buildHeaderTrailing(ProjectProvider projectProvider) {
    final projects = projectProvider.projects.take(80).toList(growable: false);
    UserProject? selectedProject;
    if (_projectId != null) {
      for (final project in projects) {
        if (project.id == _projectId) {
          selectedProject = project;
          break;
        }
      }
    }

    final allProjects = _t(context, 'dashboard_all_projects', 'All projects');
    final pickerLabel = selectedProject == null
        ? allProjects
        : _projectDisplayName(selectedProject);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactSelector(
          options: [
            CompactSelectorOption(
              value: _allProjectsOptionValue,
              label: allProjects,
            ),
            ...projects.map(
              (project) => CompactSelectorOption(
                value: project.id,
                label: _projectDisplayName(project),
              ),
            ),
          ],
          value: _projectId ?? _allProjectsOptionValue,
          displayLabel: pickerLabel,
          placeholder: allProjects,
          tooltip: _t(context, 'dashboard_switch_project', 'Switch project'),
          leadingIcon: Icons.folder_open_rounded,
          minWidth: 100,
          maxWidth: 142,
          isLoading: projectProvider.isLoading,
          onChanged: projectProvider.isLoading
              ? null
              : (value) {
                  setState(() {
                    _projectId = value == _allProjectsOptionValue
                        ? null
                        : value;
                    _activityFuture = _fetchActivity();
                  });
                },
        ),
        if (selectedProject != null)
          IconButton(
            tooltip: _t(context, 'dashboard_open_project', 'Open project'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            padding: const EdgeInsets.all(4),
            icon: const Icon(Icons.open_in_new_rounded, size: 17),
            onPressed: () => context.push('/projects/${selectedProject!.id}'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, _) =>
          FutureBuilder<PromptDailyActivity>(
            future: _activityFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const PromptActivitySkeleton();
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return CustomCard(
                  glass: true,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _t(context, 'failed_to_load', 'Failed to load'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _t(context, 'retry', 'Retry'),
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return PromptActivityHeatmap(
                activity: snapshot.data!,
                title: _t(context, 'dashboard_activity_title', 'Activity'),
                subtitle: _t(
                  context,
                  'dashboard_activity_subtitle',
                  'Recent prompt usage across your workspace.',
                ),
                headerTrailing: _buildHeaderTrailing(projectProvider),
                onDayTap: (isoDate, count) {
                  final message =
                      _t(
                            context,
                            'dashboard_prompt_activity_day_message',
                            '{count} prompts on {date}',
                          )
                          .replaceAll('{count}', count.toString())
                          .replaceAll('{date}', isoDate);
                  SnackBarHelper.showInfo(
                    context,
                    title: _t(
                      context,
                      'dashboard_prompt_activity_title',
                      'Prompt activity',
                    ),
                    message: message,
                    position: SnackBarPosition.top,
                    duration: const Duration(seconds: 2),
                  );
                },
              );
            },
          ),
    );
  }
}
