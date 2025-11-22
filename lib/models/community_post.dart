class Author {
  final String? slug;
  final String? email;
  final String? picture;

  Author({
    this.slug,
    this.email,
    this.picture,
  });

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      slug: json['slug'],
      email: json['email'],
      picture: json['picture'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'email': email,
      'picture': picture,
    };
  }
}

class CommunityPost {
  final int id;
  final String slug;
  final String title;
  final String? summary;
  final String? content;
  final String? coverUrl;
  final String? embedUrl;
  final Author? author;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final String createdAt;
  final String updatedAt;

  CommunityPost({
    required this.id,
    required this.slug,
    required this.title,
    this.summary,
    this.content,
    this.coverUrl,
    this.embedUrl,
    this.author,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    Author? author;
    if (json['author'] != null) {
      author = Author.fromJson(json['author'] as Map<String, dynamic>);
    }

    // Backward compatibility with flat structure (user_name, user_avatar, user_email)
    if (author == null && (json['user_name'] != null || json['user_avatar'] != null || json['user_email'] != null)) {
      author = Author(
        slug: json['user_id']?.toString(),
        email: json['user_email'],
        picture: json['user_avatar'],
      );
    }

    return CommunityPost(
      id: json['id'] ?? 0,
      slug: json['slug'] ?? json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      summary: json['summary'],
      content: json['content'],
      coverUrl: json['cover_url'] ?? json['image_url'],
      embedUrl: json['embed_url'],
      author: author,
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'summary': summary,
      'content': content,
      'cover_url': coverUrl,
      'embed_url': embedUrl,
      'author': author?.toJson(),
      'like_count': likeCount,
      'comment_count': commentCount,
      'is_liked': isLiked,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
