class OrganizationSummary {
  final int id;
  final String slug;
  final String name;
  final String picture;
  final String role;
  final int projectCount;

  const OrganizationSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.picture,
    required this.role,
    required this.projectCount,
  });

  bool get canManage => role == 'owner';

  factory OrganizationSummary.fromJson(Map<String, dynamic> json) {
    return OrganizationSummary(
      id: (json['id'] as num).toInt(),
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      projectCount: (json['project_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PersonalWorkspaceSummary {
  final int id;
  final String slug;
  final String name;
  final String picture;
  final int projectCount;

  const PersonalWorkspaceSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.picture,
    required this.projectCount,
  });

  factory PersonalWorkspaceSummary.fromJson(Map<String, dynamic> json) {
    return PersonalWorkspaceSummary(
      id: (json['id'] as num).toInt(),
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
      projectCount: (json['project_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrganizationContextData {
  final PersonalWorkspaceSummary personal;
  final List<OrganizationSummary> organizations;

  const OrganizationContextData({
    required this.personal,
    required this.organizations,
  });

  factory OrganizationContextData.fromJson(Map<String, dynamic> json) {
    return OrganizationContextData(
      personal: PersonalWorkspaceSummary.fromJson(
        Map<String, dynamic>.from(json['personal'] as Map),
      ),
      organizations: (json['organizations'] as List? ?? const [])
          .map(
            (item) => OrganizationSummary.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class OrganizationMemberInfo {
  final int id;
  final String email;
  final String picture;
  final String role;

  const OrganizationMemberInfo({
    required this.id,
    required this.email,
    required this.picture,
    required this.role,
  });

  factory OrganizationMemberInfo.fromJson(Map<String, dynamic> json) {
    return OrganizationMemberInfo(
      id: (json['id'] as num).toInt(),
      email: json['email']?.toString() ?? '',
      picture: json['picture']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
    );
  }
}

class OrganizationInvitationInfo {
  final int id;
  final String email;
  final String status;
  final DateTime expiresAt;

  const OrganizationInvitationInfo({
    required this.id,
    required this.email,
    required this.status,
    required this.expiresAt,
  });

  factory OrganizationInvitationInfo.fromJson(Map<String, dynamic> json) {
    return OrganizationInvitationInfo(
      id: (json['id'] as num).toInt(),
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      expiresAt: DateTime.parse(json['expires_at'].toString()),
    );
  }
}

class OrganizationWalletInfo {
  final double expiringBalance;
  final double nonexpiringBalance;
  final bool canManage;

  const OrganizationWalletInfo({
    required this.expiringBalance,
    required this.nonexpiringBalance,
    required this.canManage,
  });

  double get totalBalance => expiringBalance + nonexpiringBalance;

  factory OrganizationWalletInfo.fromJson(Map<String, dynamic> json) {
    return OrganizationWalletInfo(
      expiringBalance: (json['balance_expiring_usd'] as num?)?.toDouble() ?? 0,
      nonexpiringBalance:
          (json['balance_nonexpiring_usd'] as num?)?.toDouble() ?? 0,
      canManage: json['can_manage'] == true,
    );
  }
}

class OrganizationInvitationPreview {
  final String slug;
  final String name;
  final String picture;
  final String emailHint;
  final String status;
  final DateTime expiresAt;

  const OrganizationInvitationPreview({
    required this.slug,
    required this.name,
    required this.picture,
    required this.emailHint,
    required this.status,
    required this.expiresAt,
  });

  factory OrganizationInvitationPreview.fromJson(Map<String, dynamic> json) {
    final organization = Map<String, dynamic>.from(json['organization'] as Map);
    return OrganizationInvitationPreview(
      slug: organization['slug']?.toString() ?? '',
      name: organization['name']?.toString() ?? '',
      picture: organization['picture']?.toString() ?? '',
      emailHint: json['email_hint']?.toString() ?? '',
      status: json['status']?.toString() ?? 'expired',
      expiresAt: DateTime.parse(json['expires_at'].toString()),
    );
  }
}
