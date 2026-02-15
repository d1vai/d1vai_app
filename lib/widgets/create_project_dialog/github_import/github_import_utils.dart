String? parseGithubRepoFullName(String repoUrl) {
  final url = repoUrl.trim();
  if (url.isEmpty) return null;
  final match = RegExp(
    r'github\\.com\\/([^\\/]+)\\/([^\\/\\?#]+)',
  ).firstMatch(url);
  if (match == null) return null;
  final owner = match.group(1);
  final repo = (match.group(2) ?? '').replaceAll(RegExp(r'\\.git$'), '');
  if (owner == null || owner.isEmpty || repo.isEmpty) return null;
  return '$owner/$repo';
}

({Map<String, dynamic>? project, String? projectId}) normalizeImportedProject(
  dynamic resp,
) {
  Map<String, dynamic>? asMap;
  if (resp is Map<String, dynamic>) {
    asMap = resp;
  }
  final data = asMap;
  final project = (data != null && data['project'] is Map<String, dynamic>)
      ? (data['project'] as Map<String, dynamic>)
      : data;
  final idRaw =
      project?['id'] ??
      data?['id'] ??
      data?['project_id'] ??
      data?['projectId'] ??
      project?['project_id'] ??
      project?['projectId'];
  final projectId = idRaw?.toString();
  return (project: project, projectId: projectId);
}
