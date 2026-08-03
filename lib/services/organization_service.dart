import '../core/api_client.dart';
import '../models/organization.dart';
import '../models/project.dart';

class OrganizationService {
  final ApiClient _api;

  OrganizationService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  Future<OrganizationContextData> getContext() {
    return _api.get<OrganizationContextData>(
      '/api/organizations/context/current',
      fromJsonT: (json) => OrganizationContextData.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
  }

  Future<OrganizationSummary> createOrganization({
    required String name,
    required String slug,
    String? website,
    String? description,
    String? picture,
  }) {
    return _api.post<OrganizationSummary>(
      '/api/organizations',
      {
        'name': name.trim(),
        'slug': slug.trim().toLowerCase(),
        if ((website ?? '').trim().isNotEmpty) 'website': website!.trim(),
        if ((description ?? '').trim().isNotEmpty)
          'description': description!.trim(),
        if ((picture ?? '').trim().isNotEmpty) 'picture': picture!.trim(),
      },
      fromJsonT: (json) =>
          OrganizationSummary.fromJson(Map<String, dynamic>.from(json as Map)),
    );
  }

  Future<Map<String, dynamic>> getOrganization(String slug) {
    return _api.get<Map<String, dynamic>>('/api/organizations/$slug');
  }

  Future<Map<String, dynamic>> updateOrganization(
    String slug,
    Map<String, dynamic> payload,
  ) {
    return _api.patch<Map<String, dynamic>>(
      '/api/organizations/$slug',
      payload,
    );
  }

  Future<List<OrganizationMemberInfo>> getMembers(String slug) {
    return _api.get<List<OrganizationMemberInfo>>(
      '/api/organizations/$slug/members',
      fromJsonT: (json) => (json as List)
          .map(
            (item) => OrganizationMemberInfo.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  Future<List<OrganizationInvitationInfo>> getInvitations(String slug) {
    return _api.get<List<OrganizationInvitationInfo>>(
      '/api/organizations/$slug/invitations',
      fromJsonT: (json) => (json as List)
          .map(
            (item) => OrganizationInvitationInfo.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }

  Future<OrganizationWalletInfo> getWallet(String slug) {
    return _api.get<OrganizationWalletInfo>(
      '/api/organizations/$slug/wallet',
      fromJsonT: (json) => OrganizationWalletInfo.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
  }

  Future<Map<String, dynamic>> invite(String slug, String email) {
    return _api.post<Map<String, dynamic>>(
      '/api/organizations/$slug/invitations',
      {'email': email.trim().toLowerCase()},
    );
  }

  Future<void> revokeInvitation(String slug, int invitationId) async {
    await _api.delete<Map<String, dynamic>>(
      '/api/organizations/$slug/invitations/$invitationId',
    );
  }

  Future<Map<String, dynamic>> resendInvitation(String slug, int invitationId) {
    return _api.post<Map<String, dynamic>>(
      '/api/organizations/$slug/invitations/$invitationId/resend',
      const {},
    );
  }

  Future<void> updateMemberRole(String slug, int userId, String role) async {
    await _api.patch<Map<String, dynamic>>(
      '/api/organizations/$slug/members/$userId',
      {'role': role},
    );
  }

  Future<void> removeMember(String slug, int userId) async {
    await _api.delete<Map<String, dynamic>>(
      '/api/organizations/$slug/members/$userId',
    );
  }

  Future<Map<String, dynamic>> fundWallet(String slug, double amountUsd) {
    final idempotencyKey = 'app-${DateTime.now().microsecondsSinceEpoch}-$slug';
    return _api.post<Map<String, dynamic>>(
      '/api/organizations/$slug/wallet/fund',
      {'amount_usd': amountUsd, 'idempotency_key': idempotencyKey},
    );
  }

  Future<List<UserProject>> getPersonalProjects() {
    return _api.get<List<UserProject>>(
      '/api/projects',
      fromJsonT: (json) => (json as List)
          .map(
            (item) =>
                UserProject.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  Future<Map<String, dynamic>> transferProject(String slug, String projectId) {
    return _api.post<Map<String, dynamic>>(
      '/api/organizations/$slug/projects/${Uri.encodeComponent(projectId)}/transfer',
      const {},
    );
  }

  Future<void> leave(String slug) async {
    await _api.post<Map<String, dynamic>>(
      '/api/organizations/$slug/leave',
      const {},
    );
  }

  Future<OrganizationInvitationPreview> previewInvitation(String token) {
    return _api.get<OrganizationInvitationPreview>(
      '/api/organizations/invitations/${Uri.encodeComponent(token)}',
      fromJsonT: (json) => OrganizationInvitationPreview.fromJson(
        Map<String, dynamic>.from(json as Map),
      ),
    );
  }

  Future<Map<String, dynamic>> acceptInvitation(String token) {
    return _api.post<Map<String, dynamic>>(
      '/api/organizations/invitations/${Uri.encodeComponent(token)}/accept',
      const {},
    );
  }
}
