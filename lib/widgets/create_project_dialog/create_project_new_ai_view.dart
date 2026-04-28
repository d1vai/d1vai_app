import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/model_config.dart';
import '../../models/project.dart';
import '../../utils/project_template_localizations.dart';
import '../button.dart';
import '../input.dart';

class CreateProjectNewAiView extends StatelessWidget {
  final TextEditingController descriptionController;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onCreate;
  final List<ModelInfo> models;
  final String selectedModelId;
  final ValueChanged<String>? onModelChanged;
  final bool isModelLoading;
  final bool isWorkspaceReady;
  final List<ProjectTemplateInfo> templateOptions;
  final String selectedTemplateRepo;
  final ValueChanged<String>? onTemplateChanged;
  final bool isTemplateLoading;

  const CreateProjectNewAiView({
    super.key,
    required this.descriptionController,
    required this.errorText,
    required this.onChanged,
    required this.onCreate,
    this.models = const <ModelInfo>[],
    this.selectedModelId = '',
    this.onModelChanged,
    this.isModelLoading = false,
    this.isWorkspaceReady = false,
    this.templateOptions = const <ProjectTemplateInfo>[],
    this.selectedTemplateRepo = 'auto',
    this.onTemplateChanged,
    this.isTemplateLoading = false,
  });

  bool _canCreate(String text) {
    final t = text.trim();
    return t.isNotEmpty && t.length >= 8;
  }

  ProjectTemplateInfo? _selectedTemplate() {
    for (final template in templateOptions) {
      if (template.templateRepo == selectedTemplateRepo) {
        return template;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    final summaryText =
        loc?.translate('create_project_new_ai_summary') ??
        'In one sentence, describe pages, auth, data, and key flows (min 8 chars); we will create the project and continue in chat.';
    final selectedTemplate = _selectedTemplate();
    final localizedSelectedTemplate = selectedTemplate == null
        ? null
        : localizeProjectTemplate(selectedTemplate, locale);

    return Column(
      key: const ValueKey('new_ai'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primaryContainer.withValues(alpha: isDark ? 0.32 : 0.75),
                scheme.secondaryContainer.withValues(
                  alpha: isDark ? 0.18 : 0.52,
                ),
              ],
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: isDark ? 0.45 : 0.7,
              ),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summaryText,
                  style: TextStyle(
                    color: scheme.onSurface.withValues(
                      alpha: isDark ? 0.9 : 0.8,
                    ),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Input(
          controller: descriptionController,
          onChanged: onChanged,
          labelText:
              loc?.translate('create_project_project_description') ??
              'Project Description',
          hintText:
              loc?.translate('create_project_new_ai_hint') ??
              'Example: a team task board app with auth, roles, and database.',
          variant: InputVariant.filled,
          maxLines: 5,
          minLines: 4,
          borderRadius: 12,
          fillColor: scheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.2 : 0.28,
          ),
          borderColor: scheme.outlineVariant.withValues(
            alpha: isDark ? 0.45 : 0.7,
          ),
          focusedBorderColor: scheme.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          errorText: (errorText != null && errorText!.isNotEmpty)
              ? errorText
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          loc?.translate('create_project_template') ?? 'Template',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('create-project-template-$selectedTemplateRepo'),
              initialValue: selectedTemplateRepo,
              items: templateOptions
                  .map(
                    (template) => DropdownMenuItem<String>(
                      value: template.templateRepo,
                      child: Text(
                        localizeProjectTemplate(template, locale).name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (isTemplateLoading || onTemplateChanged == null)
                  ? null
                  : (v) {
                      if (v == null) return;
                      onTemplateChanged!(v);
                    },
              decoration: InputDecoration(
                hintText: isTemplateLoading
                    ? (loc?.translate('loading') ?? 'Loading...')
                    : (loc?.translate('create_project_select_template') ??
                          'Select template'),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.2 : 0.28,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(
                      alpha: isDark ? 0.45 : 0.7,
                    ),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 1.3),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            if (isTemplateLoading)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        if (selectedTemplate != null && localizedSelectedTemplate != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: isDark ? 0.16 : 0.22,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.35 : 0.6,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      localizedSelectedTemplate.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (selectedTemplate.featured)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(
                            alpha: isDark ? 0.24 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          localizedSelectedTemplate.featuredLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(
                          alpha: isDark ? 0.2 : 0.65,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        localizedSelectedTemplate.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  localizedSelectedTemplate.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurface.withValues(
                      alpha: isDark ? 0.82 : 0.74,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          loc?.translate('model_switch_title') ?? 'Model',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey('create-project-model-$selectedModelId'),
              initialValue: selectedModelId.trim().isEmpty
                  ? null
                  : selectedModelId,
              items: models
                  .map(
                    (m) => DropdownMenuItem<String>(
                      value: m.id,
                      child: _ModelDropdownLabel(model: m),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) => models
                  .map(
                    (m) => Align(
                      alignment: Alignment.centerLeft,
                      child: _ModelDropdownLabel(model: m, compact: true),
                    ),
                  )
                  .toList(),
              onChanged:
                  (!isWorkspaceReady ||
                      isModelLoading ||
                      onModelChanged == null)
                  ? null
                  : (v) {
                      if (v == null) return;
                      onModelChanged!(v);
                    },
              decoration: InputDecoration(
                hintText: isWorkspaceReady
                    ? (isModelLoading
                          ? (loc?.translate('loading') ?? 'Loading...')
                          : (loc?.translate('create_project_select_model') ??
                                'Select model'))
                    : (loc?.translate('create_project_waiting_workspace') ??
                          'Waiting workspace ready…'),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.2 : 0.28,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(
                      alpha: isDark ? 0.45 : 0.7,
                    ),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 1.3),
                ),
                isDense: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            if (isModelLoading)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        ListenableBuilder(
          listenable: descriptionController,
          builder: (context, _) {
            final enabled = _canCreate(descriptionController.text);
            return SizedBox(
              width: double.infinity,
              child: Button(
                onPressed: enabled ? onCreate : null,
                disabled: !enabled,
                variant: ButtonVariant.defaultVariant,
                size: ButtonSize.defaultSize,
                text:
                    loc?.translate('create_project_action') ?? 'Create Project',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ModelDropdownLabel extends StatelessWidget {
  final ModelInfo model;
  final bool compact;

  const _ModelDropdownLabel({required this.model, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badge = model.badgeLabel;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Text(
            model.displayName,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        if (badge != null) ...[
          SizedBox(width: compact ? 6 : 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 6,
              vertical: compact ? 1.5 : 2.5,
            ),
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: compact ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: scheme.tertiary.withValues(alpha: 0.24),
              ),
            ),
            child: Text(
              badge.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: compact ? 8.5 : 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.42,
                color: scheme.tertiary,
                height: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
