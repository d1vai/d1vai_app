import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/organization.dart';
import '../services/organization_service.dart';

class OrganizationProvider extends ChangeNotifier {
  static const _activeOrganizationKey = 'active_organization_id';
  final OrganizationService _service;

  OrganizationProvider({OrganizationService? service})
    : _service = service ?? OrganizationService();

  OrganizationContextData? _context;
  int? _activeOrganizationId;
  bool _loading = false;
  String? _error;
  bool _initialized = false;

  OrganizationContextData? get context => _context;
  int? get activeOrganizationId => _activeOrganizationId;
  bool get loading => _loading;
  String? get error => _error;
  OrganizationSummary? get activeOrganization {
    for (final organization in _context?.organizations ?? const []) {
      if (organization.id == _activeOrganizationId) return organization;
    }
    return null;
  }

  String get workspaceName =>
      activeOrganization?.name ??
      _context?.personal.name ??
      'Personal workspace';

  Future<void> load({bool force = false}) async {
    if (_loading || (_initialized && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getInt(_activeOrganizationKey);
      final next = await _service.getContext();
      final validStoredId =
          next.organizations.any((item) => item.id == storedId)
          ? storedId
          : null;
      _context = next;
      _activeOrganizationId = validStoredId;
      if (storedId != null && validStoredId == null) {
        await prefs.remove(_activeOrganizationKey);
      }
      _initialized = true;
    } catch (error) {
      _error = error.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> select(int? organizationId) async {
    if (organizationId != null &&
        !(_context?.organizations.any((item) => item.id == organizationId) ??
            false)) {
      return;
    }
    if (_activeOrganizationId == organizationId) return;
    _activeOrganizationId = organizationId;
    final prefs = await SharedPreferences.getInstance();
    if (organizationId == null) {
      await prefs.remove(_activeOrganizationKey);
    } else {
      await prefs.setInt(_activeOrganizationKey, organizationId);
    }
    notifyListeners();
  }

  Future<OrganizationSummary> create({
    required String name,
    required String slug,
    String? website,
    String? description,
    String? picture,
  }) async {
    final organization = await _service.createOrganization(
      name: name,
      slug: slug,
      website: website,
      description: description,
      picture: picture,
    );
    await load(force: true);
    await select(organization.id);
    return organization;
  }

  Future<void> leaveActive() async {
    final organization = activeOrganization;
    if (organization == null) return;
    await _service.leave(organization.slug);
    await select(null);
    await load(force: true);
  }

  Future<void> clear() async {
    _context = null;
    _activeOrganizationId = null;
    _initialized = false;
    _error = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeOrganizationKey);
    notifyListeners();
  }
}
