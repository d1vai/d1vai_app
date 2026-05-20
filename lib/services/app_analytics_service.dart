import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/default_tracking.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:amplitude_flutter/events/identify.dart';
import 'package:flutter/foundation.dart';

import '../models/project.dart';
import '../models/user.dart';

class AnalyticsEvents {
  static const String login = 'login';
  static const String logout = 'logout';
  static const String projectOpened = 'project-opened';
  static const String previewOpened = 'preview-opened';
}

class AppAnalyticsService {
  AppAnalyticsService._();

  static final AppAnalyticsService instance = AppAnalyticsService._();

  static const String _apiKey = String.fromEnvironment(
    'AMPLITUDE_API_KEY',
    defaultValue: '',
  );

  Amplitude? _amplitude;
  bool _initialized = false;
  bool _enabled = false;

  bool get isEnabled => _enabled;

  bool get _isSupportedPlatform {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (_apiKey.trim().isEmpty || !_isSupportedPlatform) {
      debugPrint(
        '[analytics] amplitude disabled: apiKeyMissing=${_apiKey.trim().isEmpty} supported=$_isSupportedPlatform',
      );
      return;
    }

    final amplitude = Amplitude(
      Configuration(
        apiKey: _apiKey,
        defaultTracking: const DefaultTrackingOptions(
          sessions: true,
          appLifecycles: true,
          deepLinks: true,
        ),
      ),
    );

    final built = await amplitude.isBuilt;
    if (!built) {
      debugPrint('[analytics] amplitude initialization failed');
      return;
    }

    _amplitude = amplitude;
    _enabled = true;
    debugPrint('[analytics] amplitude initialized');
  }

  Future<void> syncUser(User? user) async {
    if (!_enabled || _amplitude == null) return;

    final userId = _resolveUserId(user);
    await _amplitude!.setUserId(userId);

    if (user == null) return;

    final identify = Identify()
      ..set('user_id', user.id)
      ..set('is_onboarded', user.isOnboarded)
      ..set('is_agent', user.isAgent)
      ..set('is_admin', user.isAdmin)
      ..set('is_super_admin', user.isSuperAdmin)
      ..set('is_company', user.isCompany);

    if ((user.slug ?? '').trim().isNotEmpty) identify.set('slug', user.slug);
    if ((user.email ?? '').trim().isNotEmpty) {
      identify.set('email', user.email);
    }
    if (user.companyName.trim().isNotEmpty) {
      identify.set('company_name', user.companyName);
    }
    if (user.industry.trim().isNotEmpty) {
      identify.set('industry', user.industry);
    }
    if ((user.lastLoginType ?? '').trim().isNotEmpty) {
      identify.set('last_login_type', user.lastLoginType);
    }

    await _amplitude!.identify(identify);
  }

  Future<void> trackLogin(String method) async {
    await track(
      AnalyticsEvents.login,
      eventProperties: {'method': method},
    );
  }

  Future<void> trackLogout({String? lastLoginType}) async {
    await track(
      AnalyticsEvents.logout,
      eventProperties: {
        if ((lastLoginType ?? '').trim().isNotEmpty)
          'last_login_type': lastLoginType,
      },
    );
  }

  Future<void> trackProjectOpened(UserProject project) async {
    await track(
      AnalyticsEvents.projectOpened,
      eventProperties: {
        'project_id': project.id,
        'project_name': project.projectName,
        'has_preview': (project.preferredPreviewUrl ?? '').trim().isNotEmpty,
        'has_database': project.hasDatabaseEnabled,
        'has_payment': project.hasPaymentEnabled,
        'has_analytics': project.hasAnalyticsId,
      },
    );
  }

  Future<void> trackPreviewOpened({
    required String projectId,
    required String previewUrl,
    String source = 'chat-preview-tab',
  }) async {
    await track(
      AnalyticsEvents.previewOpened,
      eventProperties: {
        'project_id': projectId,
        'preview_url': previewUrl,
        'source': source,
      },
    );
  }

  Future<void> track(
    String eventName, {
    Map<String, dynamic>? eventProperties,
  }) async {
    if (!_enabled || _amplitude == null) return;
    await _amplitude!.track(
      BaseEvent(
        eventName,
        eventProperties: eventProperties,
      ),
    );
  }

  String? _resolveUserId(User? user) {
    if (user == null) return null;
    final sub = user.sub.trim();
    if (sub.isNotEmpty) return sub;
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email;
    return user.id > 0 ? user.id.toString() : null;
  }
}
