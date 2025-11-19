/// Onboarding 流程中的步骤枚举
enum OnboardingStep {
  invite(code: 'invite'),
  company(code: 'company'),
  avatar(code: 'avatar'),
  completed(code: 'completed');

  const OnboardingStep({required this.code});
  final String code;

  /// 从字符串获取枚举值
  static OnboardingStep fromString(String code) {
    return OnboardingStep.values.firstWhere(
      (step) => step.code == code,
      orElse: () => OnboardingStep.invite,
    );
  }

  /// 获取下一步
  OnboardingStep? getNext() {
    final index = OnboardingStep.values.indexOf(this);
    if (index < OnboardingStep.values.length - 2) {
      return OnboardingStep.values[index + 1];
    }
    return null;
  }

  /// 获取上一步
  OnboardingStep? getPrevious() {
    final index = OnboardingStep.values.indexOf(this);
    if (index > 0) {
      return OnboardingStep.values[index - 1];
    }
    return null;
  }

  /// 检查是否为最后一步
  bool get isLast => this == OnboardingStep.completed;

  /// 检查是否为第一步
  bool get isFirst => this == OnboardingStep.invite;
}

/// Onboarding 流程的数据模型
class OnboardingData {
  /// 当前步骤
  OnboardingStep currentStep;

  /// 是否已完成
  bool isCompleted;

  /// 邀请码
  String? inviteCode;

  /// 公司名称
  String? companyName;

  /// 公司网站
  String? companyWebsite;

  /// 所属行业
  String? industry;

  /// 头像 URL
  String? avatarUrl;

  OnboardingData({
    this.currentStep = OnboardingStep.invite,
    this.isCompleted = false,
    this.inviteCode,
    this.companyName,
    this.companyWebsite,
    this.industry,
    this.avatarUrl,
  });

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'currentStep': currentStep.code,
      'isCompleted': isCompleted,
      'inviteCode': inviteCode,
      'companyName': companyName,
      'companyWebsite': companyWebsite,
      'industry': industry,
      'avatarUrl': avatarUrl,
    };
  }

  /// 从 JSON 创建
  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      currentStep: OnboardingStep.fromString(json['currentStep'] ?? 'invite'),
      isCompleted: json['isCompleted'] ?? false,
      inviteCode: json['inviteCode'],
      companyName: json['companyName'],
      companyWebsite: json['companyWebsite'],
      industry: json['industry'],
      avatarUrl: json['avatarUrl'],
    );
  }

  /// 复制对象并更新字段
  OnboardingData copyWith({
    OnboardingStep? currentStep,
    bool? isCompleted,
    String? inviteCode,
    String? companyName,
    String? companyWebsite,
    String? industry,
    String? avatarUrl,
  }) {
    return OnboardingData(
      currentStep: currentStep ?? this.currentStep,
      isCompleted: isCompleted ?? this.isCompleted,
      inviteCode: inviteCode ?? this.inviteCode,
      companyName: companyName ?? this.companyName,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      industry: industry ?? this.industry,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  String toString() {
    return 'OnboardingData(currentStep: $currentStep, isCompleted: $isCompleted, inviteCode: $inviteCode, companyName: $companyName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingData &&
        other.currentStep == currentStep &&
        other.isCompleted == isCompleted &&
        other.inviteCode == inviteCode &&
        other.companyName == companyName &&
        other.companyWebsite == companyWebsite &&
        other.industry == industry &&
        other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode {
    return currentStep.hashCode ^
        isCompleted.hashCode ^
        inviteCode.hashCode ^
        companyName.hashCode ^
        companyWebsite.hashCode ^
        industry.hashCode ^
        avatarUrl.hashCode;
  }
}
