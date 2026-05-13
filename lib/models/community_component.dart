class CommunityComponent {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String category;
  final String? previewImageUrl;
  final int likeCount;
  final bool isLiked;

  const CommunityComponent({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.category,
    this.previewImageUrl,
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory CommunityComponent.fromJson(Map<String, dynamic> json) {
    return CommunityComponent(
      id: (json['id'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      previewImageUrl: (json['previewImageUrl'] ?? json['preview_image_url'])
          ?.toString(),
      likeCount: ((json['likeCount'] ?? json['like_count']) as num?)?.toInt() ??
          0,
      isLiked: json['isLiked'] == true || json['is_liked'] == true,
    );
  }

  CommunityComponent copyWith({
    String? id,
    String? slug,
    String? title,
    String? description,
    String? category,
    String? previewImageUrl,
    int? likeCount,
    bool? isLiked,
  }) {
    return CommunityComponent(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      previewImageUrl: previewImageUrl ?? this.previewImageUrl,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
