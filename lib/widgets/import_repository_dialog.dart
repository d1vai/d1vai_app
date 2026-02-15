import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/github_service.dart';
import 'snackbar_helper.dart';
import 'button.dart';
import 'card.dart';

class ImportRepositoryDialog extends StatefulWidget {
  final Map<String, dynamic> repository;

  const ImportRepositoryDialog({super.key, required this.repository});

  @override
  State<ImportRepositoryDialog> createState() => _ImportRepositoryDialogState();
}

class _ImportRepositoryDialogState extends State<ImportRepositoryDialog>
    with TickerProviderStateMixin {
  final GitHubService _githubService = GitHubService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _projectNameController;
  late TextEditingController _projectDescriptionController;
  bool _isImporting = false;
  late final AnimationController _pulseController;
  late final AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    // Pre-fill with repository information
    final repoName = widget.repository['name'] ?? '';
    final repoDescription = widget.repository['description'] ?? '';

    _projectNameController = TextEditingController(text: repoName);
    _projectDescriptionController = TextEditingController(
      text: repoDescription.isEmpty
          ? 'Imported from GitHub: ${widget.repository['full_name'] ?? repoName}'
          : repoDescription,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    _pulseController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isImporting = true;
    });
    _pulseController.repeat(reverse: true);
    _sheenController.repeat();

    try {
      final repositoryFullName = widget.repository['full_name'] ?? '';
      final defaultBranch = widget.repository['default_branch'] ?? 'main';
      final cloneUrl =
          widget.repository['clone_url'] ?? widget.repository['html_url'];
      final sshUrl = widget.repository['ssh_url'];
      final isPrivate = widget.repository['private'] == true;
      final language = widget.repository['language'];

      final result = await _githubService.importProjectFromGitHub(
        repositoryFullName: repositoryFullName,
        projectName: _projectNameController.text.trim(),
        projectDescription: _projectDescriptionController.text.trim(),
        defaultBranch: defaultBranch,
        repositoryUrl: cloneUrl?.toString(),
        repositorySshUrl: sshUrl?.toString(),
        isPrivate: isPrivate,
        primaryLanguage: language?.toString(),
      );

      if (!mounted) return;

      final project =
          (result != null && result['project'] is Map<String, dynamic>)
          ? (result['project'] as Map<String, dynamic>)
          : null;
      final projectId = project?['id']?.toString();
      if (projectId == null || projectId.isEmpty) {
        throw Exception('Failed to get project ID');
      }

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Project imported successfully!',
      );

      final router = GoRouter.of(context);
      Navigator.of(context).pop(true);
      // Navigate to project chat (align with web import flow).
      Future.microtask(
        () => router.push('/projects/$projectId/chat?tab=preview'),
      );
    } catch (e) {
      if (!mounted) return;

      SnackBarHelper.showError(
        context,
        title: 'Import Failed',
        message: 'Failed to import repository: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        _pulseController.stop();
        _pulseController.value = 0;
        _sheenController.stop();
        _sheenController.value = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final repoName = (widget.repository['name'] ?? '').toString();
    final repoFullName = (widget.repository['full_name'] ?? '').toString();
    final languageRaw = widget.repository['language'];
    final language = languageRaw?.toString();
    final stars =
        int.tryParse((widget.repository['stargazers_count'] ?? 0).toString()) ??
        0;
    final isPrivate = widget.repository['private'] == true;

    final dialog = Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.download_for_offline_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Import Repository',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isImporting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_isImporting)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  if (_isImporting) const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RepoInfoCard(
                              repoFullName: repoFullName,
                              language: language,
                              stars: stars,
                              isPrivate: isPrivate,
                              pulse: _pulseController,
                              sheen: _sheenController,
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _projectNameController,
                              decoration: _fieldDecoration(
                                theme,
                                label: 'Project Name *',
                                hint: 'Enter project name',
                                icon: Icons.folder_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Project name is required';
                                }
                                return null;
                              },
                              enabled: !_isImporting,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _projectDescriptionController,
                              decoration: _fieldDecoration(
                                theme,
                                label: 'Project Description',
                                hint: 'Enter project description (optional)',
                                icon: Icons.description_outlined,
                              ),
                              maxLines: 3,
                              enabled: !_isImporting,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'This will create a new project from: $repoName',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.62,
                                ),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Button(
                          onPressed: _isImporting
                              ? null
                              : () => Navigator.of(context).pop(),
                          disabled: _isImporting,
                          variant: ButtonVariant.ghost,
                          size: ButtonSize.defaultSize,
                          text: 'Cancel',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PrimaryImportButton(
                          isImporting: _isImporting,
                          colorScheme: colorScheme,
                          sheen: _sheenController,
                          onPressed: _isImporting ? null : _handleImport,
                        ),
                      ),
                    ],
                  ),
                  if (!_isImporting) const SizedBox(height: 2),
                  if (!_isImporting)
                    Text(
                      'Tip: importing may take a minute for larger repos.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.52),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        colorScheme.primary.withValues(alpha: 0.65),
                        colorScheme.secondary.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    if (!_isImporting) return const SizedBox.shrink();
                    final t = Curves.easeInOut.transform(
                      _pulseController.value,
                    );
                    final opacity = (isDark ? 0.10 : 0.06) * (0.35 + 0.65 * t);
                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.75, -0.85),
                            radius: 1.15,
                            colors: [
                              colorScheme.primary.withValues(alpha: 1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: !_isImporting,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final eased = Curves.easeOutCubic.transform(t);
          return Opacity(
            opacity: eased,
            child: Transform.scale(scale: 0.98 + (0.02 * eased), child: child),
          );
        },
        child: dialog,
      ),
    );
  }

  InputDecoration _fieldDecoration(
    ThemeData theme, {
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fill = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.04),
      colorScheme.surface,
    );
    final outline = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.5 : 0.65,
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18),
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1.4),
      ),
    );
  }
}

class _RepoInfoCard extends StatelessWidget {
  final String repoFullName;
  final String? language;
  final int stars;
  final bool isPrivate;
  final Animation<double> pulse;
  final Animation<double> sheen;

  const _RepoInfoCard({
    required this.repoFullName,
    required this.language,
    required this.stars,
    required this.isPrivate,
    required this.pulse,
    required this.sheen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final tagColor = isPrivate ? colorScheme.tertiary : colorScheme.primary;
    final tagBg = Color.alphaBlend(
      tagColor.withValues(alpha: isDark ? 0.18 : 0.12),
      colorScheme.surface,
    );

    return CustomCard(
      glass: true,
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPrivate ? Icons.lock_outline : Icons.folder_open_outlined,
                    size: 20,
                    color: tagColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      repoFullName.isEmpty ? 'Repository' : repoFullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tagBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: tagColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      isPrivate ? 'Private' : 'Public',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tagColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (language != null && language!.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          colorScheme.primary.withValues(alpha: 0.10),
                          colorScheme.surface,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Text(
                        language!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$stars',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([pulse, sheen]),
                builder: (context, _) {
                  final pulseT = Curves.easeInOut.transform(pulse.value);
                  final sheenT = Curves.easeOutCubic.transform(sheen.value);
                  final a = (isDark ? 0.10 : 0.07) * (0.25 + 0.75 * pulseT);
                  return Opacity(
                    opacity: a.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset((sheenT - 0.5) * 240, 0),
                      child: Transform.rotate(
                        angle: -0.35,
                        child: Container(
                          width: 170,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryImportButton extends StatelessWidget {
  final bool isImporting;
  final ColorScheme colorScheme;
  final Animation<double> sheen;
  final VoidCallback? onPressed;

  const _PrimaryImportButton({
    required this.isImporting,
    required this.colorScheme,
    required this.sheen,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          Button(
            onPressed: onPressed,
            disabled: isImporting || onPressed == null,
            variant: ButtonVariant.defaultVariant,
            size: ButtonSize.defaultSize,
            text: isImporting ? 'Importing…' : 'Import',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isImporting
                  ? SizedBox(
                      key: const ValueKey('spinner'),
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      key: ValueKey('download'),
                      size: 18,
                    ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          if (isImporting)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: sheen,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(sheen.value);
                    final opacity = (isDark ? 0.14 : 0.10) * (1 - t);
                    return Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset((t - 0.5) * 260, 0),
                        child: Transform.rotate(
                          angle: -0.35,
                          child: Container(
                            width: 160,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (isImporting)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.03 : 0.06),
                        Colors.transparent,
                        Colors.black.withValues(alpha: isDark ? 0.10 : 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
