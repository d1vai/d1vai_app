class DailyCount {
  final String date; // YYYY-MM-DD (UTC)
  final int count;

  const DailyCount({required this.date, required this.count});

  factory DailyCount.fromJson(Map<String, dynamic> json) {
    return DailyCount(
      date: (json['date'] ?? '').toString(),
      count: (json['count'] is int)
          ? json['count'] as int
          : int.tryParse((json['count'] ?? '0').toString()) ?? 0,
    );
  }
}

class PromptDailyActivity {
  final String startDate; // YYYY-MM-DD
  final String endDate; // YYYY-MM-DD
  final int days;
  final List<DailyCount> counts;

  const PromptDailyActivity({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.counts,
  });

  factory PromptDailyActivity.fromJson(Map<String, dynamic> json) {
    final rawCounts = (json['counts'] as List?) ?? const [];
    return PromptDailyActivity(
      startDate: (json['start_date'] ?? '').toString(),
      endDate: (json['end_date'] ?? '').toString(),
      days: (json['days'] is int)
          ? json['days'] as int
          : int.tryParse((json['days'] ?? '0').toString()) ?? 0,
      counts: rawCounts
          .whereType<Map<String, dynamic>>()
          .map((e) => DailyCount.fromJson(e))
          .toList(),
    );
  }
}

