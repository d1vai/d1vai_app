import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/model_config.dart';
import '../../compact_selector.dart';
import 'chat_engine_mode.dart';

class CodeTabTopBarController extends ChangeNotifier {
  TextEditingController? searchController;
  bool loadingTree = false;
  bool hasSelection = false;
  bool activeEditing = false;
  bool activeSaving = false;
  bool activeHasUnsavedChanges = false;
  bool activeWrapEnabled = false;
  bool activeFolded = false;
  bool supportsFoldAll = false;
  bool supportsFoldImports = false;
  bool supportsFoldHeader = false;
  bool hasLocalWorkspace = false;
  CodeTabTopBarSyncState syncState = CodeTabTopBarSyncState.idle;
  VoidCallback? onReload;
  VoidCallback? onAsk;
  VoidCallback? onFind;
  VoidCallback? onToggleWrap;
  VoidCallback? onSave;
  VoidCallback? onFoldAll;
  VoidCallback? onUnfoldAll;
  VoidCallback? onFoldImports;
  VoidCallback? onFoldHeader;

  void update({
    required TextEditingController? searchController,
    required bool loadingTree,
    required bool hasSelection,
    required bool activeEditing,
    required bool activeSaving,
    required bool activeHasUnsavedChanges,
    required bool activeWrapEnabled,
    required bool activeFolded,
    required bool supportsFoldAll,
    required bool supportsFoldImports,
    required bool supportsFoldHeader,
    required bool hasLocalWorkspace,
    required CodeTabTopBarSyncState syncState,
    required VoidCallback? onReload,
    required VoidCallback? onAsk,
    required VoidCallback? onFind,
    required VoidCallback? onToggleWrap,
    required VoidCallback? onSave,
    required VoidCallback? onFoldAll,
    required VoidCallback? onUnfoldAll,
    required VoidCallback? onFoldImports,
    required VoidCallback? onFoldHeader,
  }) {
    this.searchController = searchController;
    this.loadingTree = loadingTree;
    this.hasSelection = hasSelection;
    this.activeEditing = activeEditing;
    this.activeSaving = activeSaving;
    this.activeHasUnsavedChanges = activeHasUnsavedChanges;
    this.activeWrapEnabled = activeWrapEnabled;
    this.activeFolded = activeFolded;
    this.supportsFoldAll = supportsFoldAll;
    this.supportsFoldImports = supportsFoldImports;
    this.supportsFoldHeader = supportsFoldHeader;
    this.hasLocalWorkspace = hasLocalWorkspace;
    this.syncState = syncState;
    this.onReload = onReload;
    this.onAsk = onAsk;
    this.onFind = onFind;
    this.onToggleWrap = onToggleWrap;
    this.onSave = onSave;
    this.onFoldAll = onFoldAll;
    this.onUnfoldAll = onUnfoldAll;
    this.onFoldImports = onFoldImports;
    this.onFoldHeader = onFoldHeader;
    notifyListeners();
  }
}

enum CodeTabTopBarSyncState {
  idle,
  localSaved,
  queued,
  syncingCloud,
  syncingGitHub,
  synced,
  failed,
}

class ProjectChatTopBar extends StatelessWidget {
  final int currentIndex;
  final String? previewUrl;
  final CodeTabTopBarController? codeTabController;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onRefreshPreview;
  final VoidCallback onOpenInNewTab;

  const ProjectChatTopBar({
    super.key,
    required this.currentIndex,
    this.previewUrl,
    this.codeTabController,
    required this.onTabSelected,
    required this.onRefreshPreview,
    required this.onOpenInNewTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedPreviewUrl = previewUrl?.trim() ?? '';
    final showPreviewMeta = currentIndex == 0 && trimmedPreviewUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final loc = AppLocalizations.of(context);
          final compact = constraints.maxWidth < 420;
          final tabRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _TabButton(
                  isSelected: currentIndex == 0,
                  label: compact
                      ? (loc?.translate('project_chat_tab_preview_short') ??
                            'Prev')
                      : null,
                  icon: Icons.visibility_outlined,
                  onTap: () => onTabSelected(0),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabButton(
                      isSelected: currentIndex == 1,
                      label:
                          loc?.translate('project_chat_tab_files') ?? 'Files',
                      icon: Icons.folder_open_outlined,
                      onTap: () => onTabSelected(1),
                    ),
                    if (showPreviewMeta) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: _PreviewInlineMeta(url: trimmedPreviewUrl),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
          final actionsRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIconButton(
                icon: Icons.refresh,
                onPressed: onRefreshPreview,
                tooltip:
                    loc?.translate('project_chat_preview_refresh_tooltip') ??
                    'Refresh preview',
              ),
              const SizedBox(width: 6),
              _ActionIconButton(
                icon: Icons.open_in_new_outlined,
                onPressed: onOpenInNewTab,
                tooltip:
                    loc?.translate('project_chat_preview_open_tooltip') ??
                    'Open preview in browser',
              ),
            ],
          );
          final trailingWidget = switch (currentIndex) {
            0 => actionsRow,
            1 =>
              codeTabController == null
                  ? null
                  : _FilesInlineToolbar(
                      controller: codeTabController!,
                      compact: compact,
                      showSearchField: constraints.maxWidth >= 1120,
                      searchWidth: constraints.maxWidth >= 1480
                          ? 220
                          : constraints.maxWidth >= 1320
                          ? 180
                          : 148,
                    ),
            _ => null,
          };

          if (compact) {
            return Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tabRow,
                  ),
                ),
                if (trailingWidget != null) ...[
                  const SizedBox(width: 6),
                  trailingWidget,
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: tabRow,
                ),
              ),
              if (trailingWidget != null) ...[
                const SizedBox(width: 8),
                trailingWidget,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PreviewInlineMeta extends StatelessWidget {
  final String url;

  const _PreviewInlineMeta({required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Tooltip(
      message: url,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public_outlined,
              size: 12.5,
              color: cs.primary.withValues(alpha: 0.78),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _previewHost(url),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary.withValues(alpha: 0.82),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilesInlineToolbar extends StatelessWidget {
  final CodeTabTopBarController controller;
  final bool compact;
  final bool showSearchField;
  final double searchWidth;

  const _FilesInlineToolbar({
    required this.controller,
    required this.compact,
    required this.showSearchField,
    required this.searchWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final loc = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final searchController = controller.searchController;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSearchField) ...[
                SizedBox(
                  width: searchWidth,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText:
                          loc?.translate('project_chat_search_files') ??
                          'Search files…',
                      isDense: true,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: compact ? 8 : 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      suffixIcon:
                          searchController == null ||
                              searchController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: searchController.clear,
                              icon: const Icon(Icons.clear, size: 16),
                              tooltip: loc?.translate('clear') ?? 'Clear',
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _ActionIconButton(
                icon: Icons.refresh_outlined,
                onPressed: controller.loadingTree
                    ? () {}
                    : (controller.onReload ?? () {}),
                tooltip:
                    loc?.translate('project_chat_refresh_files_tooltip') ??
                    'Refresh files',
                enabled: !controller.loadingTree && controller.onReload != null,
              ),
              const SizedBox(width: 4),
              if (controller.activeEditing) ...[
                _ActionIconButton(
                  icon: Icons.search_outlined,
                  onPressed: controller.onFind ?? () {},
                  tooltip:
                      loc?.translate('project_chat_find_in_file_tooltip') ??
                      'Find in file',
                  enabled: controller.onFind != null,
                ),
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: controller.activeWrapEnabled
                      ? Icons.wrap_text
                      : Icons.wrap_text_outlined,
                  onPressed: controller.onToggleWrap ?? () {},
                  tooltip: controller.activeWrapEnabled
                      ? (loc?.translate('project_chat_disable_wrap_tooltip') ??
                            'Disable wrap')
                      : (loc?.translate('project_chat_enable_wrap_tooltip') ??
                            'Enable wrap'),
                  enabled: controller.onToggleWrap != null,
                ),
                const SizedBox(width: 4),
                if (controller.supportsFoldAll)
                  _ActionIconButton(
                    icon: controller.activeFolded
                        ? Icons.unfold_more_outlined
                        : Icons.unfold_less_outlined,
                    onPressed: controller.activeFolded
                        ? (controller.onUnfoldAll ?? () {})
                        : (controller.onFoldAll ?? () {}),
                    tooltip: controller.activeFolded
                        ? (loc?.translate('project_chat_unfold_all') ??
                              'Unfold all')
                        : (loc?.translate('project_chat_fold_all') ??
                              'Fold all'),
                    enabled: controller.activeFolded
                        ? controller.onUnfoldAll != null
                        : controller.onFoldAll != null,
                    active: controller.activeFolded,
                  ),
                if (controller.supportsFoldAll) const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.save_as_outlined,
                  onPressed: controller.activeSaving
                      ? () {}
                      : (controller.onSave ?? () {}),
                  tooltip:
                      loc?.translate('project_chat_save_file_tooltip') ??
                      'Save file',
                  enabled:
                      !controller.activeSaving &&
                      controller.activeHasUnsavedChanges &&
                      controller.onSave != null,
                ),
                const SizedBox(width: 4),
              ],
              _ActionIconButton(
                icon: Icons.tips_and_updates_outlined,
                onPressed: controller.onAsk ?? () {},
                tooltip:
                    loc?.translate('project_chat_ask_ai_file_tooltip') ??
                    'Ask AI about file',
                enabled: controller.hasSelection && controller.onAsk != null,
              ),
              const SizedBox(width: 8),
              _FilesSyncChip(
                state: controller.syncState,
                hasLocalWorkspace: controller.hasLocalWorkspace,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilesSyncChip extends StatelessWidget {
  final CodeTabTopBarSyncState state;
  final bool hasLocalWorkspace;

  const _FilesSyncChip({required this.state, required this.hasLocalWorkspace});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, color) = switch (state) {
      CodeTabTopBarSyncState.localSaved => (
        loc?.translate('project_chat_sync_saved_local') ?? 'Saved locally',
        theme.colorScheme.primary,
      ),
      CodeTabTopBarSyncState.queued => (
        loc?.translate('project_chat_sync_queued') ?? 'Queued',
        Colors.orange,
      ),
      CodeTabTopBarSyncState.syncingGitHub => (
        loc?.translate('project_chat_sync_syncing') ?? 'Syncing',
        theme.colorScheme.tertiary,
      ),
      CodeTabTopBarSyncState.syncingCloud => (
        loc?.translate('project_chat_sync_cloud') ?? 'Cloud sync',
        theme.colorScheme.secondary,
      ),
      CodeTabTopBarSyncState.synced => (
        loc?.translate('project_chat_sync_synced') ?? 'Synced',
        Colors.green,
      ),
      CodeTabTopBarSyncState.failed => (
        loc?.translate('project_chat_sync_failed') ?? 'Sync failed',
        Colors.redAccent,
      ),
      CodeTabTopBarSyncState.idle => (
        hasLocalWorkspace
            ? (loc?.translate('project_chat_sync_local_workspace') ??
                  'Local workspace')
            : (loc?.translate('project_chat_sync_cloud_workspace') ??
                  'Cloud workspace'),
        theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

String _previewHost(String url) {
  if (url.isEmpty) return 'Preview';
  try {
    return Uri.parse(url).host;
  } catch (_) {
    return url;
  }
}

class ProjectChatModelSelector extends StatelessWidget {
  final List<ModelInfo> models;
  final String selectedModelId;
  final ValueChanged<String>? onChanged;
  final bool isLoading;
  final double minWidth;
  final double maxWidth;
  final double? width;
  final String placeholder;
  final String tooltip;

  const ProjectChatModelSelector({
    super.key,
    this.models = const <ModelInfo>[],
    this.selectedModelId = '',
    this.onChanged,
    this.isLoading = false,
    this.minWidth = 120,
    this.maxWidth = 156,
    this.width,
    this.placeholder = 'Model',
    this.tooltip = 'Select model',
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;

    return SizedBox(
      width: width ?? maxWidth,
      child: CompactSelector(
        options: models
            .map(
              (m) => CompactSelectorOption(
                value: m.id,
                label: m.displayName,
                tagLabel: m.badgeLabel,
              ),
            )
            .toList(),
        value: selectedModelId.trim().isEmpty ? null : selectedModelId.trim(),
        placeholder: placeholder == 'Model'
            ? (loc?.translate('project_chat_model_placeholder') ?? 'Model')
            : placeholder,
        tooltip: tooltip == 'Select model'
            ? (loc?.translate('project_chat_model_tooltip') ?? 'Select model')
            : tooltip,
        leadingIcon: Icons.auto_awesome_rounded,
        minWidth: minWidth,
        maxWidth: maxWidth,
        borderRadius: 13,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        backgroundColor: isDark
            ? Color.alphaBlend(
                cs.primary.withValues(alpha: 0.12),
                cs.surfaceContainerHigh,
              )
            : Color.alphaBlend(
                cs.primary.withValues(alpha: 0.06),
                Colors.white,
              ),
        borderColor: isDark
            ? cs.primary.withValues(alpha: 0.28)
            : cs.outlineVariant.withValues(alpha: 0.9),
        menuBackgroundColor: isDark
            ? Color.alphaBlend(
                cs.surfaceContainerHighest.withValues(alpha: 0.96),
                cs.surface,
              )
            : Color.alphaBlend(
                Colors.white.withValues(alpha: 0.96),
                cs.surface,
              ),
        menuBorderColor: isDark
            ? cs.primary.withValues(alpha: 0.22)
            : cs.outlineVariant.withValues(alpha: 0.7),
        menuBorderRadius: 18,
        menuPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        itemHeight: 30,
        textColor: isDark ? cs.onSurface : cs.onSurface.withValues(alpha: 0.92),
        iconColor: isDark
            ? cs.primary.withValues(alpha: 0.9)
            : cs.onSurfaceVariant,
        trailingIcon: Icons.expand_more_rounded,
        isLoading: isLoading,
        onChanged: (isLoading || onChanged == null || models.isEmpty)
            ? null
            : (v) => onChanged!(v),
      ),
    );
  }
}

class ProjectChatEngineModeSegment extends StatelessWidget {
  final ChatEngineMode value;
  final String fastTooltip;
  final String thinkHardTooltip;
  final ValueChanged<ChatEngineMode>? onChanged;

  const ProjectChatEngineModeSegment({
    super.key,
    required this.value,
    required this.fastTooltip,
    required this.thinkHardTooltip,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFast = value == ChatEngineMode.fast;
    final tooltip = isFast ? fastTooltip : thinkHardTooltip;
    final borderColor = isFast
        ? Colors.green.withValues(alpha: 0.42)
        : theme.colorScheme.primary.withValues(alpha: 0.36);
    final backgroundColor = isFast
        ? Colors.green.withValues(alpha: 0.1)
        : theme.colorScheme.primary.withValues(alpha: 0.1);
    final badgeColor = isFast ? Colors.green : theme.colorScheme.primary;
    final iconColor = isFast
        ? Colors.green.shade700
        : theme.colorScheme.primary;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: isFast,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onChanged == null
                ? null
                : () => onChanged!(
                    isFast ? ChatEngineMode.thinkHard : ChatEngineMode.fast,
                  ),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.14),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: badgeColor.withValues(alpha: 0.28),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      isFast
                          ? Icons.flash_on_rounded
                          : Icons.psychology_rounded,
                      size: 11,
                      color: isFast ? Colors.green.shade900 : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    isFast
                        ? Icons.psychology_alt_rounded
                        : Icons.flash_on_rounded,
                    size: 14,
                    color: iconColor.withValues(alpha: isFast ? 0.72 : 0.82),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final bool isSelected;
  final String? label;
  final IconData icon;
  final VoidCallback onTap;

  const _TabButton({
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLabel = label != null && label!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: hasLabel
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 5)
            : const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: isSelected
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.5,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            if (hasLabel) ...[
              const SizedBox(width: 5),
              Text(
                label!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool enabled;
  final bool active;

  const _ActionIconButton({
    this.icon,
    this.iconWidget,
    required this.onPressed,
    this.tooltip,
    this.enabled = true,
    this.active = false,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final child = Container(
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: 0.28)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child:
                iconWidget ??
                Icon(
                  icon,
                  size: 15,
                  color: enabled
                      ? (active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant)
                      : theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.38,
                        ),
                ),
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.trim().isEmpty) return child;
    return Tooltip(message: tooltip, child: child);
  }
}
