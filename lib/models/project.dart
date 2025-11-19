class UserProject {
  final String id;
  final String projectName;
  final String projectDescription;
  final String createdAt;
  final String updatedAt;
  final int userId;
  final int projectPort;
  final String? emoji;
  final String? latestPreviewUrl;

  UserProject({
    required this.id,
    required this.projectName,
    required this.projectDescription,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.projectPort,
    this.emoji,
    this.latestPreviewUrl,
  });

  factory UserProject.fromJson(Map<String, dynamic> json) {
    return UserProject(
      id: json['id'],
      projectName: json['project_name'] ?? '',
      projectDescription: json['project_description'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      userId: json['user_id'] ?? 0,
      projectPort: json['project_port'] ?? 0,
      emoji: json['emoji'],
      latestPreviewUrl: json['latest_preview_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_name': projectName,
      'project_description': projectDescription,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'user_id': userId,
      'project_port': projectPort,
      'emoji': emoji,
      'latest_preview_url': latestPreviewUrl,
    };
  }
}
