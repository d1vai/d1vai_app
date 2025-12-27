import '../models/community_post.dart';

String displayCommunityPostTitle(String raw) {
  return raw.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String communityPostAuthorHeroTag(CommunityPost post) {
  return 'community_post_author_${post.id}';
}

String communityPostCoverHeroTag(CommunityPost post) {
  return 'community_post_cover_${post.id}';
}
