import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../l10n/app_localizations.dart';
import '../../models/model_config.dart';
import '../../models/project.dart';
import '../inapp_webview_settings.dart';
import '../../utils/project_style_prompt.dart';
import '../../utils/project_template_localizations.dart';
import '../button.dart';
import '../input.dart';
import '../select.dart';

const double _kComposerMinWideLines = 6;
const double _kComposerMaxWideLines = 8;
const double _kComposerMinNarrowLines = 4;
const double _kComposerMaxNarrowLines = 6;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final selectedStyle = selectedStylePreview;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final promptField = _PromptComposer(
          controller: descriptionController,
          onChanged: onChanged,
          errorText: errorText,
          wide: wide,
        );

        final submitButton = ListenableBuilder(
          listenable: descriptionController,
          builder: (context, _) {
            final enabled = _canCreate(descriptionController.text);
            return SizedBox(
              width: wide ? 220 : double.infinity,
              child: Button(
                onPressed: enabled ? onCreate : null,
                disabled: !enabled,
                variant: ButtonVariant.defaultVariant,
                size: ButtonSize.lg,
                text:
                    loc?.translate('create_project_action') ?? 'Create Project',
                height: 52,
                borderRadius: 18,
                elevation: enabled ? 1.5 : 0,
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: scheme.onPrimary,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                suffixIcon: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: enabled
                      ? scheme.onPrimary
                      : scheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            );
          },
        );

        final leftColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ControlPanel(
              compact: true,
              models: models,
              selectedModelId: selectedModelId,
              onModelChanged: onModelChanged,
              isModelLoading: isModelLoading,
              isWorkspaceReady: isWorkspaceReady,
              templateOptions: templateOptions,
              selectedTemplateRepo: selectedTemplateRepo,
              onTemplateChanged: onTemplateChanged,
              isTemplateLoading: isTemplateLoading,
              styleOptions: styleOptions,
              selectedStyleId: selectedStyleId,
              onStyleChanged: onStyleChanged,
              isStyleLoading: isStyleLoading,
              isStylePreviewLoading: isStylePreviewLoading,
              autoDeploy: autoDeploy,
              onAutoDeployChanged: onAutoDeployChanged,
            ),
            const SizedBox(height: 12),
            promptField,
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest.withValues(
                  alpha: isDark ? 0.36 : 0.82,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(
                    alpha: isDark ? 0.34 : 0.52,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Align(
                  alignment: wide ? Alignment.centerRight : Alignment.center,
                  child: submitButton,
                ),
              ),
            ),
          ],
        );

        final rightColumn = _StyleStage(
          compact: true,
          styleOptions: styleOptions,
          selectedStyleId: selectedStyleId,
          onStyleChanged: onStyleChanged,
          isStyleLoading: isStyleLoading,
          isStylePreviewLoading: isStylePreviewLoading,
          selectedStyle: selectedStyle,
          stylePreviewError: stylePreviewError,
        );

        if (wide) {
          return Row(
            key: const ValueKey('new_ai_desktop'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: leftColumn),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: rightColumn),
            ],
          );
        }

        return Column(
          key: const ValueKey('new_ai_mobile'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [leftColumn, const SizedBox(height: 18), rightColumn],
        );
      },
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final bool compact;
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
  final ValueChanged<String>? onStyleChanged;
  final bool isStyleLoading;
  final bool isStylePreviewLoading;
  final bool autoDeploy;
  final ValueChanged<bool>? onAutoDeployChanged;

  const _ControlPanel({
    this.compact = false,
    required this.models,
    required this.selectedModelId,
    required this.onModelChanged,
    required this.isModelLoading,
    required this.isWorkspaceReady,
    required this.templateOptions,
    required this.selectedTemplateRepo,
    required this.onTemplateChanged,
    required this.isTemplateLoading,
    required this.styleOptions,
    required this.selectedStyleId,
    required this.onStyleChanged,
    required this.isStyleLoading,
    required this.isStylePreviewLoading,
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
    final horizontalGap = compact ? 8.0 : 10.0;
    final deployField = _DeployField(
      compact: compact,
      autoDeploy: autoDeploy,
      onAutoDeployChanged: onAutoDeployChanged,
    );

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(
          alpha: isDark ? 0.4 : 0.85,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.42 : 0.6),
        ),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final modelField = _SelectField<String>(
                compact: compact,
                label: loc?.translate('model_switch_title') ?? 'Model',
                value: selectedModelId.trim().isEmpty ? null : selectedModelId,
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
              );

              final templateField = _SelectField<String>(
                compact: compact,
                label: loc?.translate('create_project_template') ?? 'Template',
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
              );

              final styleField = _SelectField<String>(
                compact: compact,
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
              );
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: modelField),
                    SizedBox(width: horizontalGap),
                    Expanded(child: templateField),
                    SizedBox(width: horizontalGap),
                    Expanded(child: styleField),
                    SizedBox(width: horizontalGap),
                    SizedBox(width: 172, child: deployField),
                  ],
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 176, child: modelField),
                    SizedBox(width: horizontalGap),
                    SizedBox(width: 176, child: templateField),
                    SizedBox(width: horizontalGap),
                    SizedBox(width: 176, child: styleField),
                    SizedBox(width: horizontalGap),
                    SizedBox(width: 156, child: deployField),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PromptComposer extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final bool wide;

  const _PromptComposer({
    required this.controller,
    required this.onChanged,
    required this.errorText,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final effectiveErrorText = (errorText != null && errorText!.isNotEmpty)
        ? errorText
        : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surfaceContainerLowest.withValues(
          alpha: isDark ? 0.42 : 0.88,
        ),
        border: Border.all(
          color: effectiveErrorText != null
              ? scheme.error.withValues(alpha: 0.6)
              : scheme.outlineVariant.withValues(alpha: isDark ? 0.32 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, wide ? 14 : 12, 14, wide ? 14 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc?.translate('create_project_project_description') ??
                  'Project Description',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Input(
              controller: controller,
              onChanged: onChanged,
              hintText:
                  loc?.translate('create_project_new_ai_hint') ??
                  'Example: a mobile booking app with auth, schedule, payments, and admin approvals.',
              variant: InputVariant.filled,
              maxLines: wide
                  ? _kComposerMaxWideLines.toInt()
                  : _kComposerMaxNarrowLines.toInt(),
              minLines: wide
                  ? _kComposerMinWideLines.toInt()
                  : _kComposerMinNarrowLines.toInt(),
              borderRadius: 16,
              fillColor: scheme.surface.withValues(alpha: isDark ? 0.26 : 0.74),
              borderColor: Colors.transparent,
              focusedBorderColor: scheme.primary.withValues(alpha: 0.84),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                height: 1.4,
              ),
              textStyle: theme.textTheme.bodyLarge?.copyWith(
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              errorText: effectiveErrorText,
            ),
          ],
        ),
      ),
    );
  }
}

class _DeployField extends StatelessWidget {
  final bool compact;
  final bool autoDeploy;
  final ValueChanged<bool>? onAutoDeployChanged;

  const _DeployField({
    required this.compact,
    required this.autoDeploy,
    required this.onAutoDeployChanged,
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
        Text(
          loc?.translate('create_project_deploy') ?? 'Deploy',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: compact ? 4 : 6),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 44 : 48),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: isDark ? 0.22 : 0.74),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: isDark ? 0.35 : 0.52,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  autoDeploy
                      ? (loc?.translate('create_project_toggle_on') ?? 'On')
                      : (loc?.translate('create_project_toggle_off') ?? 'Off'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Transform.scale(
                scale: compact ? 0.88 : 0.94,
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: autoDeploy,
                  onChanged: onAutoDeployChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StyleStage extends StatelessWidget {
  final bool compact;
  final List<ProjectStyleInfo> styleOptions;
  final String selectedStyleId;
  final ProjectStyleInfo? selectedStyle;
  final ValueChanged<String>? onStyleChanged;
  final bool isStyleLoading;
  final bool isStylePreviewLoading;
  final String? stylePreviewError;

  const _StyleStage({
    this.compact = false,
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
    final previewHtml =
        (selectedStyle?.previewHtml != null &&
            selectedStyle!.previewHtml!.trim().isNotEmpty)
        ? selectedStyle!.previewHtml!
        : buildCreateProjectFoundationPreviewHtml(
            title:
                selectedStyle?.name ??
                (loc?.translate('create_project_style_foundation_name') ??
                    'Foundation'),
            summary:
                selectedStyle?.summary ??
                loc?.translate('create_project_style_foundation_summary') ??
                'Stay close to the template baseline. No curated art direction will be injected into generation.',
            previewBaselineLabel:
                loc?.translate('create_project_preview_baseline_label') ??
                'Preview baseline',
            neutralLabel:
                loc?.translate('create_project_preview_neutral_label') ??
                'Neutral',
            foundationModeLabel:
                loc?.translate('create_project_style_foundation_name') ??
                'Foundation',
            headline:
                loc?.translate('create_project_preview_fallback_headline') ??
                'Template-first mobile preview.',
            createAction:
                loc?.translate('create_project_action') ?? 'Create Project',
            densityLabel:
                loc?.translate('create_project_preview_density_label') ??
                'Density',
            densityValue:
                loc?.translate('create_project_preview_density_value') ??
                'Compact',
            densityBody:
                loc?.translate('create_project_preview_density_body') ??
                'Controls stay dense so the preview keeps most of the attention.',
            outputLabel:
                loc?.translate('create_project_preview_output_label') ??
                'Output',
            outputValue:
                loc?.translate('create_project_preview_output_value') ??
                'Ready',
            outputBody:
                loc?.translate('create_project_preview_output_body') ??
                'Used whenever a specific style preview is not available yet.',
            structureLabel:
                loc?.translate('create_project_preview_structure_label') ??
                'Structure',
            structureItems: <String>[
              loc?.translate('create_project_preview_structure_hero') ?? 'Hero',
              loc?.translate('create_project_preview_structure_metrics') ??
                  'Metrics',
              loc?.translate('create_project_preview_structure_features') ??
                  'Features',
              loc?.translate('create_project_preview_structure_cta') ?? 'CTA',
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
              Center(
                child: _PhonePreviewFrame(
                  html: previewHtml,
                  loading: isStyleLoading || isStylePreviewLoading,
                  loadingLabel:
                      loc?.translate('create_project_style_preview_loading') ??
                      'Loading preview...',
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
  final bool compact;
  final String label;
  final T? value;
  final String hint;
  final List<SelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isLoading;

  const _SelectField({
    this.compact = false,
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
        SizedBox(height: compact ? 4 : 6),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            Select<T>(
              value: value,
              isExpanded: true,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 11 : 13,
                vertical: compact ? 9 : 11,
              ),
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
  final bool loading;
  final String loadingLabel;

  const _PhonePreviewFrame({
    required this.html,
    required this.loading,
    required this.loadingLabel,
  });

  @override
  State<_PhonePreviewFrame> createState() => _PhonePreviewFrameState();
}

class _PhonePreviewFrameState extends State<_PhonePreviewFrame> {
  InAppWebViewController? _controller;
  bool _webReady = false;

  bool get _hasHtml => (widget.html ?? '').trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant _PhonePreviewFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasHtml) {
      _webReady = true;
      return;
    }
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
      width: 252,
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(30),
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
            width: 74,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 236,
              height: 500,
              color: scheme.surface,
              child: Stack(
                children: [
                  if (_hasHtml)
                    InAppWebView(
                      initialData: InAppWebViewInitialData(
                        data: widget.html!,
                        baseUrl: WebUri('https://d1v.ai'),
                      ),
                      initialSettings: buildAppWebViewSettings(
                        transparentBackground: true,
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
                    ),
                  if (_hasHtml && (widget.loading || !_webReady))
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
                                widget.loadingLabel,
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
        ],
      ),
    );
  }
}

String buildCreateProjectFoundationPreviewHtml({
  required String title,
  required String summary,
  required String previewBaselineLabel,
  required String neutralLabel,
  required String foundationModeLabel,
  required String headline,
  required String createAction,
  required String densityLabel,
  required String densityValue,
  required String densityBody,
  required String outputLabel,
  required String outputValue,
  required String outputBody,
  required String structureLabel,
  required List<String> structureItems,
}) {
  String escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  final chips = structureItems
      .map((item) => '<span class="chip">${escape(item)}</span>')
      .join();

  return '''
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      :root {
        color-scheme: light;
        --bg: #f3f6fb;
        --panel: rgba(255,255,255,0.82);
        --line: rgba(15,23,42,0.08);
        --text: #0f172a;
        --muted: #5b6475;
        --accent: #111827;
        --accent-soft: rgba(17,24,39,0.08);
      }
      :root.dark {
        color-scheme: dark;
        --bg: #020617;
        --panel: rgba(15,23,42,0.88);
        --line: rgba(148,163,184,0.16);
        --text: #f8fafc;
        --muted: #94a3b8;
        --accent: #e2e8f0;
        --accent-soft: rgba(226,232,240,0.1);
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        font-family: Inter, ui-sans-serif, system-ui, sans-serif;
        color: var(--text);
        background:
          radial-gradient(circle at top, rgba(59,130,246,0.14), transparent 28%),
          linear-gradient(180deg, var(--bg), #dbe5f1);
      }
      .shell { min-height: 100vh; padding: 20px 16px 24px; display: flex; flex-direction: column; gap: 14px; }
      .topbar, .hero, .card, .metric {
        border: 1px solid var(--line);
        border-radius: 22px;
        background: var(--panel);
        backdrop-filter: blur(18px);
      }
      .topbar { padding: 12px 14px; display: flex; align-items: center; justify-content: space-between; }
      .hero, .card, .metric { padding: 14px; }
      .eyebrow { font-size: 10px; text-transform: uppercase; letter-spacing: 0.18em; color: var(--muted); }
      h1 { margin: 12px 0 10px; font-size: 30px; line-height: 1.02; letter-spacing: -0.05em; }
      p { margin: 0; color: var(--muted); line-height: 1.5; font-size: 13px; }
      strong { display: block; margin-top: 14px; font-size: 20px; letter-spacing: -0.04em; }
      .cta { display: inline-flex; margin-top: 16px; border-radius: 999px; background: var(--accent); color: var(--bg); padding: 10px 14px; font-size: 12px; font-weight: 700; }
      .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
      .chips { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 16px; }
      .chip { border-radius: 999px; padding: 7px 10px; background: var(--accent-soft); font-size: 11px; font-weight: 600; }
    </style>
  </head>
  <body>
    <main class="shell">
      <section class="topbar">
        <div>
          <div class="eyebrow">${escape(previewBaselineLabel)}</div>
          <strong style="margin:4px 0 0;font-size:16px">${escape(title)}</strong>
        </div>
        <span class="chip">${escape(neutralLabel)}</span>
      </section>
      <section class="hero">
        <div class="eyebrow">${escape(foundationModeLabel)}</div>
        <h1>${escape(headline)}</h1>
        <p>${escape(summary)}</p>
        <div class="cta">${escape(createAction)}</div>
      </section>
      <section class="grid">
        <article class="metric">
          <div class="eyebrow">${escape(densityLabel)}</div>
          <strong>${escape(densityValue)}</strong>
          <p>${escape(densityBody)}</p>
        </article>
        <article class="metric">
          <div class="eyebrow">${escape(outputLabel)}</div>
          <strong>${escape(outputValue)}</strong>
          <p>${escape(outputBody)}</p>
        </article>
      </section>
      <section class="card">
        <div class="eyebrow">${escape(structureLabel)}</div>
        <div class="chips">$chips</div>
      </section>
    </main>
  </body>
</html>
''';
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
