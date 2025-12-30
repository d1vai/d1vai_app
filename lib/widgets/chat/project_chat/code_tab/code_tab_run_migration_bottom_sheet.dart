import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../services/d1vai_service.dart';
import '../../../snackbar_helper.dart';

enum _MigrationStep { plan, validate, approval, autoReview, execute }

Future<void> showRunSqlMigrationBottomSheet(
  BuildContext context, {
  required String projectId,
  required String sql,
  required String sourcePath,
}) async {
  if (sql.trim().isEmpty) {
    SnackBarHelper.showError(
      context,
      title: 'SQL is empty',
      message: 'This SQL file has no content to run.',
      duration: const Duration(seconds: 2),
    );
    return;
  }

  final hostContext = context;
  await showModalBottomSheet<void>(
    context: hostContext,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          clipBehavior: Clip.antiAlias,
          child: _RunSqlMigrationSheet(
            projectId: projectId,
            sql: sql,
            sourcePath: sourcePath,
            onSendToChat: (prompt) {
              final encoded = Uri.encodeQueryComponent(prompt);
              Navigator.of(sheetContext).pop();
              GoRouter.of(hostContext).push(
                '/projects/$projectId/chat?autoprompt=$encoded',
              );
            },
          ),
        ),
      );
    },
  );
}

class _RunSqlMigrationSheet extends StatefulWidget {
  final String projectId;
  final String sql;
  final String sourcePath;
  final void Function(String prompt)? onSendToChat;

  const _RunSqlMigrationSheet({
    required this.projectId,
    required this.sql,
    required this.sourcePath,
    this.onSendToChat,
  });

  @override
  State<_RunSqlMigrationSheet> createState() => _RunSqlMigrationSheetState();
}

class _RunSqlMigrationSheetState extends State<_RunSqlMigrationSheet> {
  final D1vaiService _service = D1vaiService();

  bool _running = false;
  bool _completed = false;
  String? _error;

  _MigrationStep? _step;
  final Set<_MigrationStep> _finished = <_MigrationStep>{};

  String? _planId;
  String? _approvalId;
  String? _approvalToken;

  Map<String, dynamic>? _autoReviewStatus;

  List<_StepInfo> get _steps => const [
    _StepInfo(_MigrationStep.plan, 'Plan'),
    _StepInfo(_MigrationStep.validate, 'Validate'),
    _StepInfo(_MigrationStep.approval, 'Create Approval'),
    _StepInfo(_MigrationStep.autoReview, 'Auto Review'),
    _StepInfo(_MigrationStep.execute, 'Execute'),
  ];

  String _tipText() {
    final s = _step;
    if (_completed) return 'Done.';
    if (!_running || s == null) return 'Review the steps before running.';
    switch (s) {
      case _MigrationStep.plan:
        return 'Planning migration…';
      case _MigrationStep.validate:
        return 'Validating on shadow DB…';
      case _MigrationStep.approval:
        return 'Creating approval…';
      case _MigrationStep.autoReview:
        return 'Running safety checks…';
      case _MigrationStep.execute:
        return 'Executing changes…';
    }
  }

  bool get _hasAttempted {
    return _running ||
        _completed ||
        _step != null ||
        _finished.isNotEmpty ||
        _planId != null ||
        _approvalId != null ||
        _autoReviewStatus != null;
  }

  Future<void> _run() async {
    if (_running) return;
    if (widget.projectId.trim().isEmpty) return;
    if (widget.sql.trim().isEmpty) return;

    setState(() {
      _running = true;
      _completed = false;
      _error = null;
      _step = null;
      _finished.clear();
      _planId = null;
      _approvalId = null;
      _approvalToken = null;
      _autoReviewStatus = null;
    });

    try {
      // Plan
      setState(() => _step = _MigrationStep.plan);
      final plan = await _service.migrationPlan(
        projectId: widget.projectId,
        intent: 'codeview_sql_file',
        proposedSql: widget.sql,
      );
      final planId = (plan['plan_id'] ?? '').toString();
      if (planId.isEmpty) throw Exception('Failed to create migration plan');
      setState(() {
        _planId = planId;
        _finished.add(_MigrationStep.plan);
      });

      // Validate
      setState(() => _step = _MigrationStep.validate);
      await _service.migrationValidate(planId: planId);
      setState(() => _finished.add(_MigrationStep.validate));

      // Approval
      setState(() => _step = _MigrationStep.approval);
      final appr = await _service.migrationCreateApproval(
        planId: planId,
        riskSummary: 'CodeViewer: ${widget.sourcePath}',
        expiresInMinutes: 10,
      );
      final approvalId = (appr['approval_id'] ?? '').toString();
      final approvalToken = (appr['approval_token'] ?? '').toString();
      if (approvalId.isEmpty) throw Exception('Failed to create approval');
      setState(() {
        _approvalId = approvalId;
        _approvalToken = approvalToken.isNotEmpty ? approvalToken : null;
        _finished.add(_MigrationStep.approval);
      });

      // Auto-review
      setState(() => _step = _MigrationStep.autoReview);
      final auto = await _service.migrationAutoReview(approvalId);
      final status = (auto['status'] ?? '').toString();
      setState(() {
        _autoReviewStatus = auto;
        _finished.add(_MigrationStep.autoReview);
      });
      if (status != 'approved') {
        setState(() {
          _running = false;
          _error = null;
        });
        return;
      }
      final token = (auto['approval_token'] ?? '').toString();
      if (token.isEmpty) {
        throw Exception('Missing approval token, cannot execute migration');
      }
      setState(() {
        _approvalToken = token;
      });

      // Execute
      setState(() => _step = _MigrationStep.execute);
      await _service.migrationExecute(planId: planId, approvalToken: token);
      setState(() => _finished.add(_MigrationStep.execute));

      if (!mounted) return;
      setState(() {
        _completed = true;
      });
      SnackBarHelper.showSuccess(
        context,
        title: 'Migration executed',
        message: 'SQL migration executed successfully.',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      SnackBarHelper.showError(
        context,
        title: 'Migration failed',
        message: e.toString(),
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _runAnyway() async {
    final approvalId = _approvalId;
    final approvalToken = _approvalToken;
    final planId = _planId;
    if (approvalId == null || approvalToken == null || planId == null) return;
    if (_running) return;

    setState(() {
      _error = null;
      _running = true;
      _step = _MigrationStep.execute;
    });
    try {
      await _service.migrationApprove(approvalId);
      await _service.migrationExecute(
        planId: planId,
        approvalToken: approvalToken,
      );
      setState(() {
        _finished.add(_MigrationStep.execute);
        _completed = true;
      });
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Migration executed',
        message: 'SQL migration executed successfully.',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      SnackBarHelper.showError(
        context,
        title: 'Migration failed',
        message: e.toString(),
        duration: const Duration(seconds: 3),
      );
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  void _sendReasonsToChat() {
    final rawReasons = _autoReviewStatus?['reasons'];
    final reasons =
        (rawReasons is List) ? rawReasons.map((e) => e.toString()).toList() : <String>[];
    final file = widget.sourcePath.trim().isNotEmpty
        ? widget.sourcePath.trim()
        : 'migration.sql';

    final prompt = [
      'Please optimize the SQL migration $file to be safer and non-destructive.',
      'Auto-review rejected it for the following reasons:',
      ...reasons.map((r) => '- $r'),
      '',
      'Rewrite a safer migration that:',
      '- avoids mass DELETE/UPDATE without a restrictive WHERE and sensible batching;',
      '- uses CREATE INDEX CONCURRENTLY (or an equivalent online strategy) where applicable;',
      '- maintains transactional safety and minimizes locks;',
      '- aims for zero-downtime if schema changes are needed.',
      '',
      'Return only the improved SQL and a brief rationale.',
    ].join('\n');

    final cb = widget.onSendToChat;
    if (cb == null) {
      SnackBarHelper.showError(
        context,
        title: 'Send to chat',
        message: 'Chat is not available from this screen.',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    cb(prompt);
  }

  ButtonStyle _primaryActionStyle({
    required Color background,
    required Color foreground,
  }) {
    final theme = Theme.of(context);
    final borderAlpha = theme.brightness == Brightness.dark ? 0.55 : 0.35;
    return ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: background,
      foregroundColor: foreground,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: background.withValues(alpha: borderAlpha)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (_autoReviewStatus?['status'] ?? '').toString();
    final rejected = !_running && !_completed && status == 'rejected';
    final showRetry = _hasAttempted && !_running && !_completed;
    final primaryLabel = _completed ? 'Done' : (showRetry ? 'Retry' : 'Run');
    final primaryBg = _completed
        ? (theme.brightness == Brightness.dark
              ? Colors.green.shade500
              : Colors.green.shade700)
        : theme.colorScheme.primary;
    final primaryFg = _completed ? Colors.white : theme.colorScheme.onPrimary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.play_circle_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Run SQL Migration',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sourcePath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _running ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_running || _completed) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _completed ? 1 : null,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _tipText(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StepGrid(
                    steps: _steps,
                    current: _step,
                    finished: _finished,
                    errorStep: _error != null ? _step : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBox(text: _error!),
                  ],
                ] else ...[
                  Text(
                    'This will run the following steps:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final s in _steps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(width: 8),
                          Text(s.label, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                ],
                if (rejected) ...[
                  const SizedBox(height: 12),
                  _RejectedBox(
                    riskScore: _autoReviewStatus?['risk_score'],
                    reasons: (_autoReviewStatus?['reasons'] is List)
                        ? (_autoReviewStatus!['reasons'] as List).map((e) => e.toString()).toList()
                        : const <String>[],
                    onRunAnyway: _runAnyway,
                    onSendToChat: _sendReasonsToChat,
                  ),
                ],
              ],
            ),
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + MediaQuery.of(context).padding.bottom + 6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _running ? null : () => Navigator.of(context).pop(),
                    child: Text(_completed ? 'Close' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _running
                        ? null
                        : _completed
                        ? () => Navigator.of(context).pop()
                        : _run,
                    style: _primaryActionStyle(
                      background: primaryBg,
                      foreground: primaryFg,
                    ),
                    child: _running
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text('Running'),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _completed
                                    ? Icons.check_circle
                                    : showRetry
                                    ? Icons.refresh
                                    : Icons.play_arrow,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(primaryLabel),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepInfo {
  final _MigrationStep key;
  final String label;

  const _StepInfo(this.key, this.label);
}

class _StepGrid extends StatelessWidget {
  final List<_StepInfo> steps;
  final _MigrationStep? current;
  final Set<_MigrationStep> finished;
  final _MigrationStep? errorStep;

  const _StepGrid({
    required this.steps,
    required this.current,
    required this.finished,
    required this.errorStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final s in steps)
          SizedBox(
            width: (MediaQuery.of(context).size.width - 12 * 2 - 10) / 2,
            child: _StepChip(
              label: s.label,
              state: errorStep == s.key
                  ? _StepState.error
                  : finished.contains(s.key)
                  ? _StepState.done
                  : current == s.key
                  ? _StepState.active
                  : _StepState.idle,
              theme: theme,
            ),
          ),
      ],
    );
  }
}

enum _StepState { idle, active, done, error }

class _StepChip extends StatelessWidget {
  final String label;
  final _StepState state;
  final ThemeData theme;

  const _StepChip({
    required this.label,
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color tint;
    switch (state) {
      case _StepState.done:
        icon = Icons.check_circle;
        tint = theme.brightness == Brightness.dark
            ? Colors.green.shade300
            : Colors.green.shade700;
        break;
      case _StepState.error:
        icon = Icons.error;
        tint = theme.colorScheme.error;
        break;
      case _StepState.active:
        icon = Icons.autorenew;
        tint = theme.colorScheme.primary;
        break;
      case _StepState.idle:
        icon = Icons.circle_outlined;
        tint = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
        break;
    }

    final bg = Color.alphaBlend(
      tint.withValues(alpha: 0.08),
      theme.colorScheme.surface,
    );
    final border = Color.alphaBlend(
      tint.withValues(alpha: 0.25),
      theme.colorScheme.outlineVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          if (state == _StepState.active)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: tint),
            )
          else
            Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;

  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _RejectedBox extends StatelessWidget {
  final dynamic riskScore;
  final List<String> reasons;
  final VoidCallback onRunAnyway;
  final VoidCallback onSendToChat;

  const _RejectedBox({
    required this.riskScore,
    required this.reasons,
    required this.onRunAnyway,
    required this.onSendToChat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = riskScore is num ? riskScore as num : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: theme.brightness == Brightness.dark ? 0.14 : 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: theme.brightness == Brightness.dark ? 0.35 : 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Auto-review rejected',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.brightness == Brightness.dark
                  ? Colors.amber.shade200
                  : Colors.amber.shade900,
            ),
          ),
          if (score != null) ...[
            const SizedBox(height: 6),
            Text(
              'Risk score: ${score.toStringAsFixed(2)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.brightness == Brightness.dark
                    ? Colors.amber.shade200.withValues(alpha: 0.9)
                    : Colors.amber.shade900.withValues(alpha: 0.9),
              ),
            ),
          ],
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final r in reasons.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: theme.textTheme.bodySmall),
                    Expanded(
                      child: Text(
                        r,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onRunAnyway,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: theme.colorScheme.error.withValues(
                          alpha: theme.brightness == Brightness.dark ? 0.55 : 0.35,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Run it anyway'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSendToChat,
                  child: const Text('Send to chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
