import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

String _t(BuildContext context, String key, String fallback) {
  final value = AppLocalizations.of(context)?.translate(key);
  if (value == null || value == key) return fallback;
  return value;
}

String formatTimeAgo(BuildContext context, String isoString) {
  try {
    final dateTime = DateTime.parse(isoString);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return _t(context, 'project_overview_time_just_now', 'just now');
    }
    if (difference.inMinutes < 60) {
      return _t(
        context,
        'project_overview_time_minutes_ago',
        '{minutes}m ago',
      ).replaceAll('{minutes}', difference.inMinutes.toString());
    }
    if (difference.inHours < 24) {
      return _t(
        context,
        'project_overview_time_hours_ago',
        '{hours}h ago',
      ).replaceAll('{hours}', difference.inHours.toString());
    }
    if (difference.inDays < 7) {
      return _t(
        context,
        'project_overview_time_days_ago',
        '{days}d ago',
      ).replaceAll('{days}', difference.inDays.toString());
    }

    final localeTag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMd(localeTag).format(dateTime);
  } catch (_) {
    return '';
  }
}

String getDeploymentLabel(BuildContext context, String? url) {
  if (url == null || url.isEmpty) {
    return _t(
      context,
      'project_overview_deployment_configure_later',
      'Configure later',
    );
  }
  try {
    final uri = Uri.parse(url);
    return uri.host;
  } catch (_) {
    return url;
  }
}
