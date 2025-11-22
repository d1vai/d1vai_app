import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user.dart';
import '../services/d1vai_service.dart';
import '../widgets/avatar_image.dart';
import '../providers/auth_provider.dart';

/// 我的邀请页面 - 展示当前用户已邀请的用户列表，邀请码和邀请链接
class MyInvitesScreen extends StatefulWidget {
  const MyInvitesScreen({super.key});

  @override
  State<MyInvitesScreen> createState() => _MyInvitesScreenState();
}

class _MyInvitesScreenState extends State<MyInvitesScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  List<User> _invitees = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvitees();
  }

  /// 加载邀请用户列表
  Future<void> _loadInvitees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invitees = await _d1vaiService.getMyInvitees();
      setState(() {
        _invitees = invitees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load invited users: $e';
        _isLoading = false;
      });
    }
  }

  /// 复制邀请链接
  Future<void> _copyInviteLink(String inviteLink) async {
    await Clipboard.setData(ClipboardData(text: inviteLink));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite link copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 分享邀请链接
  Future<void> _shareInviteLink(String inviteLink, String inviteCode) async {
    await Share.share(
      'Join me on D1V.ai! Use my invite code: $inviteCode\n\n$inviteLink',
      subject: 'Join D1V.ai',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final inviteCode = user?.inviteCode ?? '';
    final inviteLink = 'https://d1v.ai/login?invite=$inviteCode';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Invites'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvitees,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInvitees,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 邀请码和链接卡片
            _buildInviteLinkCard(inviteCode, inviteLink),
            const SizedBox(height: 16),

            // 邀请规则卡片
            _buildInviteRulesCard(),
            const SizedBox(height: 24),

            // 已邀请用户列表标题
            const Text(
              'Invited Users',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 已邀请用户列表内容
            _buildInviteesList(),
          ],
        ),
      ),
    );
  }

  /// 构建邀请链接卡片
  Widget _buildInviteLinkCard(String inviteCode, String inviteLink) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和图标
            Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Share your invite',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Each code can accept up to 3 users within a rolling 7-day window.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // 邀请码展示（6位数字样式）
            const Text(
              'Invite Code',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildInviteCodeDisplay(inviteCode),
            const SizedBox(height: 20),

            // 邀请链接
            const Text(
              'Invite Link',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildInviteLinkDisplay(inviteLink),
            const SizedBox(height: 16),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _copyInviteLink(inviteLink),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy Link'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareInviteLink(inviteLink, inviteCode),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建邀请码展示（6位数字样式）
  Widget _buildInviteCodeDisplay(String inviteCode) {
    final codeChars = inviteCode.padRight(6, ' ').split('');

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(
        6,
        (index) => Container(
          width: 48,
          height: 56,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              codeChars[index],
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: codeChars[index] == ' '
                    ? Colors.grey.shade400
                    : Colors.black87,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建邀请链接展示
  Widget _buildInviteLinkDisplay(String inviteLink) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              inviteLink,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建邀请规则卡片
  Widget _buildInviteRulesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Invitation Rules',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Simple rules to keep invites fair.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            _buildRuleItem(
              'Each invite code can accept up to 3 users within a rolling 7-day window.',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              'Invites are accepted upon login using the invite link.',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              'You can share your invite link with anyone you trust.',
            ),
          ],
        ),
      ),
    );
  }

  /// 构建规则项
  Widget _buildRuleItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建已邀请用户列表
  Widget _buildInviteesList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInvitees,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_invitees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 装饰性背景圆环
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.group_add_outlined,
                  size: 64,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No invited users yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.deepPurple.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Share your invite code to get started!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Tip: Each code can accept up to 3 users\nwithin a rolling 7-day window',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _invitees.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invitee = _invitees[index];
        return _buildInviteeCard(invitee);
      },
    );
  }

  Widget _buildInviteeCard(User invitee) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: 可以导航到用户详情页面
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 头像
              Hero(
                tag: 'user_avatar_${invitee.id}',
                child: AvatarImage(
                  imageUrl: invitee.picture.isEmpty
                      ? 'placeholder'
                      : invitee.picture,
                  size: 56,
                  borderRadius: BorderRadius.circular(28),
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),

              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 邮箱或用户名
                    Text(
                      (invitee.email?.isNotEmpty ?? false)
                          ? invitee.email!
                          : (invitee.sub.isNotEmpty
                              ? invitee.sub
                              : 'User #${invitee.id}'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 公司名称
                    if (invitee.companyName.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              invitee.companyName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    // 行业
                    if (invitee.industry.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.work,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              invitee.industry,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // 箭头图标
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
