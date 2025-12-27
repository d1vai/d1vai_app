String formatTimeAgo(String isoString) {
  try {
    final dateTime = DateTime.parse(isoString);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  } catch (_) {
    return '';
  }
}

String getDeploymentLabel(String? url) {
  if (url == null || url.isEmpty) {
    return 'Configure later';
  }
  try {
    final uri = Uri.parse(url);
    return uri.host;
  } catch (_) {
    return url;
  }
}

