import 'package:flutter/material.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/avatar_image.dart';
import '../utils/error_utils.dart';

class InvitesListScreen extends StatefulWidget {
  const InvitesListScreen({super.key});

  @override
  State<InvitesListScreen> createState() => _InvitesListScreenState();
}

class _InvitesListScreenState extends State<InvitesListScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  bool _isLoading = false;
  List<dynamic> _invitedUsers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvitedUsers();
  }

  Future<void> _loadInvitedUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _d1vaiService.getMyInvitees();
      setState(() {
        _invitedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      final message = humanizeError(e);
      setState(() {
        _error = message;
        _isLoading = false;
      });
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Invites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadInvitedUsers,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load invited users',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInvitedUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_invitedUsers.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.group_add_outlined,
        title: 'No Invites Yet',
        message: 'You haven\'t invited any friends yet.\nShare your invite code to get started!',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvitedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _invitedUsers.length,
        itemBuilder: (context, index) {
          final user = _invitedUsers[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final email = user['email'] as String? ?? 'Unknown';
    final joinedAt = user['joined_at'] as String?;
    final companyName = user['company_name'] as String?;
    final avatarUrl = user['picture'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar with real image support (PNG and SVG)
            AvatarImage(
              imageUrl: avatarUrl ?? '',
              size: 48,
              placeholderText: email.isNotEmpty ? email[0].toUpperCase() : '?',
            ),
            const SizedBox(width: 16),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (companyName != null && companyName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      companyName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (joinedAt != null) ...[
                    Text(
                      'Joined ${_formatDate(joinedAt)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.month}/${date.day}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }
}
