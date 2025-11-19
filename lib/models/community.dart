/// 社区帖子作者信息
class Author {
  final String slug;
  final String email;
  final String picture;

  Author({required this.slug, required this.email, required this.picture});

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      slug: json['slug'] ?? '',
      email: json['email'] ?? '',
      picture: json['picture'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'slug': slug, 'email': email, 'picture': picture};
  }

  @override
  String toString() {
    return 'Author(slug: $slug, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Author &&
        other.slug == slug &&
        other.email == email &&
        other.picture == picture;
  }

  @override
  int get hashCode {
    return slug.hashCode ^ email.hashCode ^ picture.hashCode;
  }
}

/// 社区帖子模型
class CommunityPost {
  final int id;
  final String projectId;
  final int userId;
  final String slug;
  final String title;
  final String summary;
  final String coverUrl;
  final List<String> tags;
  final String status;
  final DateTime publishedAt;
  final String? embedUrl;
  final Author author;

  CommunityPost({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.slug,
    required this.title,
    required this.summary,
    required this.coverUrl,
    required this.tags,
    required this.status,
    required this.publishedAt,
    this.embedUrl,
    required this.author,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] ?? 0,
      projectId: json['project_id'] ?? '',
      userId: json['user_id'] ?? 0,
      slug: json['slug'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      coverUrl: json['cover_url'] ?? '',
      tags: json['tags'] != null ? List<String>.from(json['tags']) : <String>[],
      status: json['status'] ?? 'published',
      publishedAt: DateTime.parse(
        json['published_at'] ?? DateTime.now().toIso8601String(),
      ),
      embedUrl: json['embed_url'],
      author: Author.fromJson(json['author'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'user_id': userId,
      'slug': slug,
      'title': title,
      'summary': summary,
      'cover_url': coverUrl,
      'tags': tags,
      'status': status,
      'published_at': publishedAt.toIso8601String(),
      'embed_url': embedUrl,
      'author': author.toJson(),
    };
  }

  @override
  String toString() {
    return 'CommunityPost(id: $id, title: $title, author: ${author.slug})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommunityPost &&
        other.id == id &&
        other.slug == slug &&
        other.title == title;
  }

  @override
  int get hashCode {
    return id.hashCode ^ slug.hashCode ^ title.hashCode;
  }
}

/// 社区帖子列表响应
class CommunityPostsResponse {
  final int code;
  final String message;
  final List<CommunityPost> data;
  final int total;

  CommunityPostsResponse({
    required this.code,
    required this.message,
    required this.data,
    required this.total,
  });

  factory CommunityPostsResponse.fromJson(Map<String, dynamic> json) {
    final postsJson = json['data'] as List?;
    final posts = postsJson != null
        ? postsJson.map((post) => CommunityPost.fromJson(post)).toList()
        : <CommunityPost>[];

    return CommunityPostsResponse(
      code: json['code'] ?? 0,
      message: json['message'] ?? 'success',
      data: posts,
      total: json['total'] ?? posts.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'data': data.map((post) => post.toJson()).toList(),
      'total': total,
    };
  }

  @override
  String toString() {
    return 'CommunityPostsResponse(code: $code, total: $total, posts: ${data.length})';
  }
}

/// 社区帖子查询参数
class CommunityPostsQuery {
  final String? q;
  final int limit;
  final int offset;
  final String sort;
  final String order;

  CommunityPostsQuery({
    this.q,
    this.limit = 20,
    this.offset = 0,
    this.sort = 'published_at',
    this.order = 'desc',
  });

  /// 转换为查询参数 Map
  Map<String, dynamic> toQueryParams() {
    return {
      if (q != null && q!.isNotEmpty) 'q': q,
      'limit': limit.toString(),
      'offset': offset.toString(),
      'sort': sort,
      'order': order,
    };
  }

  /// 从查询参数创建
  factory CommunityPostsQuery.fromQueryParams(Map<String, String> params) {
    return CommunityPostsQuery(
      q: params['q'],
      limit: int.tryParse(params['limit'] ?? '20') ?? 20,
      offset: int.tryParse(params['offset'] ?? '0') ?? 0,
      sort: params['sort'] ?? 'published_at',
      order: params['order'] ?? 'desc',
    );
  }

  @override
  String toString() {
    return 'CommunityPostsQuery(q: $q, limit: $limit, offset: $offset, sort: $sort, order: $order)';
  }
}
