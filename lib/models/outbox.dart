class OutboxItem {
  final String id;
  final String prompt;
  final DateTime enqueuedAt;
  final bool needsCooldownAfterIdle;
  final OutboxItemStatus status;
  final String? error;

  const OutboxItem({
    required this.id,
    required this.prompt,
    required this.enqueuedAt,
    this.needsCooldownAfterIdle = false,
    this.status = OutboxItemStatus.queued,
    this.error,
  });

  OutboxItem copyWith({
    String? id,
    String? prompt,
    DateTime? enqueuedAt,
    bool? needsCooldownAfterIdle,
    OutboxItemStatus? status,
    String? error,
  }) {
    return OutboxItem(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      enqueuedAt: enqueuedAt ?? this.enqueuedAt,
      needsCooldownAfterIdle:
          needsCooldownAfterIdle ?? this.needsCooldownAfterIdle,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

enum OutboxItemStatus { queued, running, failed }

enum OutboxMode {
  idle,
  waitingModel,
  waitingWorkspace,
  waitingTask,
  dispatching,
  pausedError,
}
