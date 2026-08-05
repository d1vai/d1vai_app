class CommunitySkill {
  final int id;
  final String slug;
  final String name;
  final String description;
  final String category;
  final List<String> sourceTags;
  final String repoUrl;
  final String? version;
  final String? riskLevel;
  final String? publisherName;
  final String? publisherLogin;
  final String? publisherAvatarUrl;

  const CommunitySkill({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.category,
    required this.sourceTags,
    required this.repoUrl,
    this.version,
    this.riskLevel,
    this.publisherName,
    this.publisherLogin,
    this.publisherAvatarUrl,
  });

  factory CommunitySkill.fromJson(Map<String, dynamic> json) {
    final publisher = json['publisher'];
    final rawTags = json['source_tags'];
    return CommunitySkill(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      sourceTags: rawTags is List
          ? rawTags.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      repoUrl: json['repo_url']?.toString() ?? '',
      version: json['version']?.toString(),
      riskLevel: json['risk_level']?.toString(),
      publisherName: publisher is Map
          ? (publisher['name'] ?? publisher['username'] ?? publisher['email'])
                ?.toString()
          : null,
      publisherLogin: publisher is Map ? publisher['login']?.toString() : null,
      publisherAvatarUrl: publisher is Map
          ? publisher['avatar_url']?.toString()
          : null,
    );
  }
}
