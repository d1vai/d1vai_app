import '../models/project.dart';

String? preferredPreviewUrlFromProject(UserProject? project) {
  return project?.preferredPreviewUrl;
}

String? preferredPreviewUrlFromPayload(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final candidates = <String?>[
    payload['custom_url']?.toString(),
    payload['production_url']?.toString(),
    payload['latest_dev_deployment_url']?.toString(),
    payload['latest_preview_url']?.toString(),
    payload['vercel_url']?.toString(),
    payload['url']?.toString(),
  ];

  for (final raw in candidates) {
    final next = (raw ?? '').trim();
    if (next.isNotEmpty) return next;
  }
  return null;
}
