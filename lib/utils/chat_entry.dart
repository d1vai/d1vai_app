import '../models/project.dart';
import 'preview_url.dart';

String resolveProjectChatSubTab(UserProject? project) {
  final previewUrl = (preferredPreviewUrlFromProject(project) ?? '').trim();
  return previewUrl.isNotEmpty ? 'preview' : 'code';
}

String buildProjectChatDetailRoute(UserProject project) {
  final subTab = resolveProjectChatSubTab(project);
  return '/projects/${project.id}?tab=chat&chatTab=$subTab';
}
