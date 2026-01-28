import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/prompt_activity.dart';
import 'card.dart';

class PromptActivityHeatmap extends StatelessWidget {
  final PromptDailyActivity activity;
  final double cellSize;
  final double gap;
  final int? weeks;

  const PromptActivityHeatmap({
    super.key,
    required this.activity,
    this.cellSize = 12,
    this.gap = 4,
    this.weeks,
  });

  int _levelFor(int count, int max) {
    if (count <= 0) return 0;
    if (max <= 0) return 1;
    final s = math.log(count + 1) / math.log(max + 1);
    if (s <= 0.25) return 1;
    if (s <= 0.5) return 2;
    if (s <= 0.75) return 3;
    return 4;
  }

  Color _cellColor(BuildContext context, int level) {
    // Match d1vai web heatmap colors (GitHub-style): muted -> emerald ramp,
    // with a dedicated dark palette for better contrast.
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (level <= 0) {
      return scheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.15 : 0.25,
      );
    }

    if (!isDark) {
      return switch (level) {
        1 => const Color(0xFFA7F3D0).withValues(alpha: 0.90),
        2 => const Color(0xFF6EE7B7).withValues(alpha: 0.95),
        3 => const Color(0xFF34D399),
        _ => const Color(0xFF10B981),
      };
    }

    return switch (level) {
      1 => const Color(0xFF064E3B).withValues(alpha: 0.55),
      2 => const Color(0xFF065F46).withValues(alpha: 0.75),
      3 => const Color(0xFF047857),
      _ => const Color(0xFF059669),
    };
  }

  DateTime _parseUtcDate(String iso) => DateTime.parse('${iso}T00:00:00Z');

  String _fmtIsoDateUtc(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  DateTime _addDaysUtc(DateTime d, int days) => d.add(Duration(days: days));

  String _fmtMonthShort(Locale locale, String iso) {
    try {
      return DateFormat.MMM(locale.toString()).format(_parseUtcDate(iso));
    } catch (_) {
      return '';
    }
  }

  String _fmtWeekdayShort(Locale locale, DateTime d) {
    try {
      return DateFormat.E(locale.toString()).format(d);
    } catch (_) {
      return '';
    }
  }

  String _fmtDate(Locale locale, String iso, {required bool compact}) {
    try {
      final dt = _parseUtcDate(iso);
      return (compact
              ? DateFormat.MMMd(locale.toString())
              : DateFormat.yMMMd(locale.toString()))
          .format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final isCompact = MediaQuery.sizeOf(context).width < 380;

    final items = activity.counts;
    final maxCount = items.fold<int>(0, (m, it) => math.max(m, it.count));
    final total = items.fold<int>(0, (m, it) => m + it.count);

    final byDate = <String, int>{for (final it in items) it.date: it.count};

    // Align to Sunday (UTC), matching d1vai web (GitHub-style).
    final endDate = _parseUtcDate(activity.endDate);
    final endDow = endDate.weekday % 7; // 0=Sun..6=Sat
    final endWeekSunday = endDate.subtract(Duration(days: endDow));

    final requestedWeeks = weeks ?? (activity.days / 7).ceil();
    final clampedWeeks = math.min(52, math.max(12, requestedWeeks));
    final startDate = _addDaysUtc(endWeekSunday, -(clampedWeeks - 1) * 7);
    final startIso = _fmtIsoDateUtc(startDate);
    final endIso = activity.endDate;

    final cellPitch = cellSize + gap;
    final gridHeight = (cellSize * 7) + (gap * 6);
    final gridWidth = (cellPitch * clampedWeeks) - gap;
    const monthLabelHeight = 16.0;

    return CustomCard(
      glass: true,
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc?.translate('prompt_activity_title') ?? 'Prompt activity',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            if (!isCompact)
              Text(
                '${_fmtDate(locale, startIso, compact: false)} - ${_fmtDate(locale, endIso, compact: false)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              )
            else
              Text(
                '${_fmtDate(locale, startIso, compact: true)} - ${_fmtDate(locale, endIso, compact: true)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: monthLabelHeight + 6 + gridHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left weekday labels (GitHub-style: Mon/Wed/Fri).
                    Padding(
                      padding: EdgeInsets.only(top: monthLabelHeight + 6),
                      child: SizedBox(
                        width: 28,
                        height: gridHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: List.generate(7, (row) {
                            String label = '';
                            if (row == 1) {
                              label = _fmtWeekdayShort(
                                locale,
                                DateTime.utc(2024, 1, 1),
                              );
                            } else if (row == 3) {
                              label = _fmtWeekdayShort(
                                locale,
                                DateTime.utc(2024, 1, 3),
                              );
                            } else if (row == 5) {
                              label = _fmtWeekdayShort(
                                locale,
                                DateTime.utc(2024, 1, 5),
                              );
                            }

                            return SizedBox(
                              height: row == 6 ? cellSize : cellPitch,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  label,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    height: 1.0,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: gridWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month labels (positioned so they can overflow across columns).
                          SizedBox(
                            height: monthLabelHeight,
                            width: gridWidth,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: List.generate(clampedWeeks, (w) {
                                final weekStart = _addDaysUtc(startDate, w * 7);
                                final weekStartIso = _fmtIsoDateUtc(weekStart);
                                final showMonth = weekStart.day <= 7;
                                final label = showMonth
                                    ? _fmtMonthShort(locale, weekStartIso)
                                    : null;
                                if (label == null || label.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Positioned(
                                  left: w * cellPitch,
                                  top: 0,
                                  child: Text(
                                    label,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      height: 1.0,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: gridHeight,
                            width: gridWidth,
                            child: GridView.builder(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7, // 7 rows (Sun..Sat)
                                    mainAxisSpacing: gap,
                                    crossAxisSpacing: gap,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: clampedWeeks * 7,
                              itemBuilder: (context, index) {
                                final col = index ~/ 7;
                                final row = index % 7;
                                final d = _addDaysUtc(
                                  startDate,
                                  (col * 7) + row,
                                );
                                if (d.isAfter(endDate)) {
                                  return Container(
                                    width: cellSize,
                                    height: cellSize,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(
                                            alpha:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? 0.15
                                                : 0.25,
                                          ),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant
                                            .withValues(
                                              alpha:
                                                  theme.brightness ==
                                                      Brightness.dark
                                                  ? 0.35
                                                  : 0.5,
                                            ),
                                      ),
                                    ),
                                  );
                                }

                                final iso = _fmtIsoDateUtc(d);
                                final count = byDate[iso] ?? 0;
                                final lvl = _levelFor(count, maxCount);
                                final color = _cellColor(context, lvl);
                                final tooltip =
                                    '${_fmtDate(locale, iso, compact: false)} • $count ${loc?.translate('prompts_unit') ?? 'prompts'}';

                                return Tooltip(
                                  message: tooltip,
                                  child: Container(
                                    width: cellSize,
                                    height: cellSize,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant
                                            .withValues(
                                              alpha:
                                                  theme.brightness ==
                                                      Brightness.dark
                                                  ? 0.35
                                                  : 0.5,
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${loc?.translate('prompt_activity_total') ?? 'Total:'} $total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      loc?.translate('legend_less') ?? 'Less',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(5, (i) {
                        return Container(
                          width: cellSize,
                          height: cellSize,
                          margin: EdgeInsets.only(right: i == 4 ? 0 : 4),
                          decoration: BoxDecoration(
                            color: _cellColor(context, i),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(
                                    alpha: theme.brightness == Brightness.dark
                                        ? 0.35
                                        : 0.5,
                                  ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loc?.translate('legend_more') ?? 'More',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
