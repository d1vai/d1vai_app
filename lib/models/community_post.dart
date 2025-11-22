class CommunityPost {
  final int id;
  final int userId;
  final String? userName;
  final String? userAvatar;
  final String? userEmail;
  final String title;
  final String content;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final String createdAt;
  final String updatedAt;

  CommunityPost({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatar,
    this.userEmail,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'],
      userAvatar: json['user_avatar'],
      userEmail: json['user_email'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      imageUrl: json['image_url'],
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
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'user_email': userEmail,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'like_count': likeCount,
      'comment_count': commentCount,
      'is_liked': isLiked,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
