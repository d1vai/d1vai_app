import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/team.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';
import '../widgets/avatar_image.dart';

class TeamDetailScreen extends StatefulWidget {
  final Team team;

  const TeamDetailScreen({
    super.key,
    required this.team,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  late Team _team;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _team = widget.team;
  }

  Future<void> _showInviteMemberDialog() async {
    final emailController = TextEditingController();
    String selectedRole = 'member';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                hintText: 'Enter email address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'member', child: Text('Member')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value != null) {
                  selectedRole = value;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                Navigator.of(context).pop({
                  'email': email,
                  'role': selectedRole,
                });
              }
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    ).then((result) async {
      if (result == null) return;

      try {
        setState(() {
          _isLoading = true;
        });

        await _d1vaiService.inviteTeamMember(
          _team.id,
          result['email'],
          result['role'],
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          SnackBarHelper.showSuccess(
            context,
            title: 'Success',
            message: 'Invitation sent successfully',
          );
        }
      } catch (e) {
        debugPrint('Failed to invite member: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to send invitation: $e',
          );
        }
      }
    });
  }

  Future<void> _shareInviteLink() async {
    final inviteLink = 'https://d1v.ai/join-team/${_team.id}';
    final message = 'Join my team "${_team.name}" on d1v.ai!\n\n$inviteLink';

    try {
      await Share.share(message, subject: 'Join ${_team.name}');
    } catch (e) {
      // 如果分享失败，回退到复制链接
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: inviteLink));
      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Copied',
        message: 'Invite link copied to clipboard',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_team.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareInviteLink,
            tooltip: 'Share team invite',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // TODO: Refresh team data
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 团队信息卡片
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.deepPurple.shade100,
                                radius: 30,
                                child: Text(
                                  _team.name.isNotEmpty
                                      ? _team.name[0].toUpperCase()
                                      : 'T',
                                  style: TextStyle(
                                    color: Colors.deepPurple.shade700,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _team.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_team.description?.isNotEmpty ?? false) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _team.description!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_team.memberCount} ${_team.memberCount == 1 ? 'member' : 'members'}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _shareInviteLink,
                                  icon: const Icon(Icons.share, size: 18),
                                  label: const Text('Share Invite Link'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _showInviteMemberDialog,
                                  icon: const Icon(Icons.person_add, size: 18),
                                  label: const Text('Invite Member'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 团队成员列表
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Team Members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        if (_team.members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No members yet',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        else
                          ..._team.members.map((member) {
                            return ListTile(
                              leading: AvatarImage(
                                imageUrl: member.picture?.isNotEmpty == true
                                    ? member.picture!
                                    : 'placeholder',
                                size: 40,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: Text(
                                member.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                member.email ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: member.roleColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: member.roleColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  member.roleDisplayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: member.roleColor,
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
