class ProjectCustomDomainDnsRecord {
  final String type;
  final String domain;
  final String value;
  final String? purpose;
  final String? reason;

  const ProjectCustomDomainDnsRecord({
    required this.type,
    required this.domain,
    required this.value,
    this.purpose,
    this.reason,
  });

  factory ProjectCustomDomainDnsRecord.fromJson(Map<String, dynamic> json) {
    return ProjectCustomDomainDnsRecord(
      type: json['type']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      purpose: json['purpose']?.toString(),
      reason: json['reason']?.toString(),
    );
  }
}

class ProjectCustomDomain {
  final int id;
  final String domain;
  final String status;
  final bool isPrimary;
  final List<ProjectCustomDomainDnsRecord> verification;
  final String? errorMessage;
  final String? verifiedAt;
  final String? createdAt;

  const ProjectCustomDomain({
    required this.id,
    required this.domain,
    required this.status,
    required this.isPrimary,
    required this.verification,
    this.errorMessage,
    this.verifiedAt,
    this.createdAt,
  });

  bool get isVerified => status.toLowerCase() == 'verified';
  bool get isPendingDns => status.toLowerCase() == 'pending_dns';

  factory ProjectCustomDomain.fromJson(Map<String, dynamic> json) {
    final rawVerification = json['verification'];
    final records = rawVerification is List
        ? rawVerification
              .whereType<Map>()
              .map(
                (item) => ProjectCustomDomainDnsRecord.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
        : const <ProjectCustomDomainDnsRecord>[];
    return ProjectCustomDomain(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      domain: json['domain']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending_dns',
      isPrimary: json['is_primary'] == true,
      verification: records,
      errorMessage: json['error_message']?.toString(),
      verifiedAt: json['verified_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ProjectCustomDomainsResponse {
  final String? platformDomain;
  final List<ProjectCustomDomain> domains;

  const ProjectCustomDomainsResponse({
    required this.platformDomain,
    required this.domains,
  });

  factory ProjectCustomDomainsResponse.fromJson(Map<String, dynamic> json) {
    final rawDomains = json['domains'];
    return ProjectCustomDomainsResponse(
      platformDomain: json['platform_domain']?.toString(),
      domains: rawDomains is List
          ? rawDomains
                .whereType<Map>()
                .map(
                  (item) => ProjectCustomDomain.fromJson(
                    item.cast<String, dynamic>(),
                  ),
                )
                .toList(growable: false)
          : const <ProjectCustomDomain>[],
    );
  }
}
