import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../l10n/app_localizations.dart';
import '../../models/model_config.dart';
import '../../models/project.dart';
import '../../utils/project_style_prompt.dart';
import '../../utils/project_template_localizations.dart';
import '../button.dart';
import '../input.dart';
import '../select.dart';

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
  final List<ProjectStyleInfo> styleOptions;
  final String selectedStyleId;
  final ProjectStyleInfo? selectedStylePreview;
  final ValueChanged<String>? onStyleChanged;
  final bool isStyleLoading;
  final bool isStylePreviewLoading;
  final String? stylePreviewError;
  final bool autoDeploy;
  final ValueChanged<bool>? onAutoDeployChanged;

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
    this.styleOptions = const <ProjectStyleInfo>[],
    this.selectedStyleId = defaultProjectStyleId,
    this.selectedStylePreview,
    this.onStyleChanged,
    this.isStyleLoading = false,
    this.isStylePreviewLoading = false,
    this.stylePreviewError,
    this.autoDeploy = true,
    this.onAutoDeployChanged,
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
    final selectedTemplate = _selectedTemplate();
    final localizedSelectedTemplate = selectedTemplate == null
        ? null
        : localizeProjectTemplate(selectedTemplate, locale);
    final selectedStyle = selectedStylePreview;

    return Column(
      key: const ValueKey('new_ai'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                scheme.tertiary.withValues(alpha: isDark ? 0.16 : 0.08),
                scheme.surface,
              ],
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: isDark ? 0.45 : 0.7,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc?.translate('create_project_new_project_title') ??
                    'New Project',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                loc?.translate('create_project_new_ai_summary') ??
                    'Pick the model, template, and deployment mode. Then describe the product once and verify the visual direction on the phone preview.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  color: scheme.onSurface.withValues(alpha: 0.76),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ControlPanel(
          models: models,
          selectedModelId: selectedModelId,
          onModelChanged: onModelChanged,
          isModelLoading: isModelLoading,
          isWorkspaceReady: isWorkspaceReady,
          templateOptions: templateOptions,
          selectedTemplateRepo: selectedTemplateRepo,
          onTemplateChanged: onTemplateChanged,
          isTemplateLoading: isTemplateLoading,
          autoDeploy: autoDeploy,
          onAutoDeployChanged: onAutoDeployChanged,
        ),
        const SizedBox(height: 18),
        Input(
          controller: descriptionController,
          onChanged: onChanged,
          labelText:
              loc?.translate('create_project_project_description') ??
              'Project Description',
          hintText:
              loc?.translate('create_project_new_ai_hint') ??
              'Example: a mobile booking app with auth, schedule, payments, and admin approvals.',
          variant: InputVariant.filled,
          maxLines: 6,
          minLines: 5,
          borderRadius: 18,
          fillColor: scheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.18 : 0.24,
          ),
          borderColor: scheme.outlineVariant.withValues(
            alpha: isDark ? 0.4 : 0.55,
          ),
          focusedBorderColor: scheme.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          errorText: (errorText != null && errorText!.isNotEmpty)
              ? errorText
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          localizedSelectedTemplate?.description ??
              (loc?.translate('create_project_form_desc_tip') ??
                  'Describe the core screens, data model, and critical flows.'),
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.35,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        _StyleStage(
          styleOptions: styleOptions,
          selectedStyleId: selectedStyleId,
          onStyleChanged: onStyleChanged,
          isStyleLoading: isStyleLoading,
          isStylePreviewLoading: isStylePreviewLoading,
          selectedStyle: selectedStyle,
          stylePreviewError: stylePreviewError,
        ),
        const SizedBox(height: 22),
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
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final List<ModelInfo> models;
  final String selectedModelId;
  final ValueChanged<String>? onModelChanged;
  final bool isModelLoading;
  final bool isWorkspaceReady;
  final List<ProjectTemplateInfo> templateOptions;
  final String selectedTemplateRepo;
  final ValueChanged<String>? onTemplateChanged;
  final bool isTemplateLoading;
  final bool autoDeploy;
  final ValueChanged<bool>? onAutoDeployChanged;

  const _ControlPanel({
    required this.models,
    required this.selectedModelId,
    required this.onModelChanged,
    required this.isModelLoading,
    required this.isWorkspaceReady,
    required this.templateOptions,
    required this.selectedTemplateRepo,
    required this.onTemplateChanged,
    required this.isTemplateLoading,
    required this.autoDeploy,
    required this.onAutoDeployChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(
          alpha: isDark ? 0.4 : 0.85,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.42 : 0.6),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SelectField<String>(
                  label: loc?.translate('model_switch_title') ?? 'Model',
                  value: selectedModelId.trim().isEmpty
                      ? null
                      : selectedModelId,
                  hint: isWorkspaceReady
                      ? (isModelLoading
                            ? (loc?.translate('loading') ?? 'Loading...')
                            : (loc?.translate('create_project_select_model') ??
                                  'Select model'))
                      : (loc?.translate('create_project_waiting_workspace') ??
                            'Waiting workspace ready…'),
                  items: models
                      .map(
                        (m) => SelectItem<String>(
                          value: m.id,
                          child: _ModelDropdownLabel(model: m, compact: true),
                        ),
                      )
                      .toList(),
                  isLoading: isModelLoading,
                  onChanged:
                      (!isWorkspaceReady ||
                          isModelLoading ||
                          onModelChanged == null)
                      ? null
                      : (v) {
                          if (v == null) return;
                          onModelChanged!(v);
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SelectField<String>(
                  label:
                      loc?.translate('create_project_template') ?? 'Template',
                  value: selectedTemplateRepo,
                  hint: isTemplateLoading
                      ? (loc?.translate('loading') ?? 'Loading...')
                      : (loc?.translate('create_project_select_template') ??
                            'Select template'),
                  items: templateOptions
                      .map(
                        (template) => SelectItem<String>(
                          value: template.templateRepo,
                          child: Text(
                            localizeProjectTemplate(template, locale).name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  isLoading: isTemplateLoading,
                  onChanged: (isTemplateLoading || onTemplateChanged == null)
                      ? null
                      : (v) {
                          if (v == null) return;
                          onTemplateChanged!(v);
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: isDark ? 0.22 : 0.74),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.35 : 0.52,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc?.translate('project_section_deploy_label') ??
                            'Deploy',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        autoDeploy
                            ? 'Preview deploy will start automatically.'
                            : 'Create project without immediate deployment.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(value: autoDeploy, onChanged: onAutoDeployChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleStage extends StatelessWidget {
  final List<ProjectStyleInfo> styleOptions;
  final String selectedStyleId;
  final ProjectStyleInfo? selectedStyle;
  final ValueChanged<String>? onStyleChanged;
  final bool isStyleLoading;
  final bool isStylePreviewLoading;
  final String? stylePreviewError;

  const _StyleStage({
    required this.styleOptions,
    required this.selectedStyleId,
    required this.selectedStyle,
    required this.onStyleChanged,
    required this.isStyleLoading,
    required this.isStylePreviewLoading,
    required this.stylePreviewError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SelectField<String>(
          label: loc?.translate('create_project_style') ?? 'Style',
          value: selectedStyleId,
          hint: isStyleLoading
              ? (loc?.translate('loading') ?? 'Loading...')
              : (loc?.translate('create_project_select_style') ??
                    'Select style'),
          items: styleOptions
              .map(
                (style) => SelectItem<String>(
                  value: style.id,
                  child: Text(
                    style.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          isLoading: isStyleLoading || isStylePreviewLoading,
          onChanged: (isStyleLoading || onStyleChanged == null)
              ? null
              : (v) {
                  if (v == null) return;
                  onStyleChanged!(v);
                },
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surfaceContainerHighest.withValues(
                  alpha: isDark ? 0.22 : 0.45,
                ),
                scheme.surface.withValues(alpha: isDark ? 0.9 : 0.96),
              ],
            ),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: isDark ? 0.36 : 0.5,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedStyle?.name ?? 'Foundation',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedStyle?.summary ??
                              'Template-first direction with no extra art direction.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.35,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedStyle != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(
                          alpha: isDark ? 0.22 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        selectedStyle!.category,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if (stylePreviewError != null &&
                  stylePreviewError!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  stylePreviewError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: _PhonePreviewFrame(
                  html: selectedStyle?.previewHtml,
                  title: selectedStyle?.name ?? 'Foundation preview',
                  loading: isStyleLoading || isStylePreviewLoading,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String hint;
  final List<SelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isLoading;

  const _SelectField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            Select<T>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              backgroundColor: scheme.surface.withValues(
                alpha: isDark ? 0.22 : 0.74,
              ),
              hint: Text(
                hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              items: items,
              onChanged: onChanged,
            ),
            if (isLoading)
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
      ],
    );
  }
}

class _PhonePreviewFrame extends StatefulWidget {
  final String? html;
  final String title;
  final bool loading;

  const _PhonePreviewFrame({
    required this.html,
    required this.title,
    required this.loading,
  });

  @override
  State<_PhonePreviewFrame> createState() => _PhonePreviewFrameState();
}

class _PhonePreviewFrameState extends State<_PhonePreviewFrame> {
  InAppWebViewController? _controller;
  bool _webReady = false;

  @override
  void didUpdateWidget(covariant _PhonePreviewFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html &&
        _controller != null &&
        widget.html != null) {
      _webReady = false;
      _controller!.loadData(
        data: widget.html!,
        baseUrl: WebUri('https://d1v.ai'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: 286,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.28),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              width: 266,
              height: 520,
              color: scheme.surface,
              child: Stack(
                children: [
                  if ((widget.html ?? '').trim().isNotEmpty)
                    InAppWebView(
                      initialData: InAppWebViewInitialData(
                        data: widget.html!,
                        baseUrl: WebUri('https://d1v.ai'),
                      ),
                      initialSettings: InAppWebViewSettings(
                        transparentBackground: true,
                        javaScriptEnabled: true,
                        supportZoom: false,
                        disableHorizontalScroll: false,
                        disableVerticalScroll: false,
                      ),
                      onWebViewCreated: (controller) {
                        _controller = controller;
                      },
                      onLoadStop: (_, url) {
                        if (!mounted) return;
                        setState(() {
                          _webReady = true;
                        });
                      },
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'No style preview available.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  if (widget.loading || !_webReady)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.74),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Loading preview...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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

    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: compact ? FontWeight.w600 : FontWeight.w500,
    );
    final badgeWidget = badge == null
        ? null
        : Container(
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
          );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              model.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (badgeWidget != null) ...[const SizedBox(width: 6), badgeWidget],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            model.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        if (badgeWidget != null) ...[const SizedBox(width: 8), badgeWidget],
      ],
    );
  }
}
