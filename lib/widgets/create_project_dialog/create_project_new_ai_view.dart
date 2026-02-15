import 'package:flutter/material.dart';

import '../../models/model_config.dart';
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
  });

  bool _canCreate(String text) {
    final t = text.trim();
    return t.isNotEmpty && t.length >= 8;
  }

  bool _isChineseLocale(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode.toLowerCase();
    return code == 'zh';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isZh = _isChineseLocale(context);

    final summaryText = isZh
        ? '一句话写清页面、登录、数据和关键流程（至少 8 个字），系统会自动创建项目并在聊天里继续完成。'
        : 'In one sentence, describe pages, auth, data, and key flows (min 8 chars); we will create the project and continue in chat.';

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
          labelText: isZh ? '项目描述' : 'Project Description',
          hintText: isZh
              ? '例如：一个支持团队协作与任务看板的应用，带登录、权限和数据库。'
              : 'Example: a team task board app with auth, roles, and database.',
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
          isZh ? '模型' : 'Model',
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
                      child: Text(m.name, overflow: TextOverflow.ellipsis),
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
                          ? (isZh ? '正在加载模型…' : 'Loading models…')
                          : (isZh ? '选择模型' : 'Select model'))
                    : (isZh ? '等待工作区就绪…' : 'Waiting workspace ready…'),
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
                text: isZh ? '创建项目' : 'Create Project',
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
