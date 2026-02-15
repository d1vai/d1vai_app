import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import 'snackbar_helper.dart';

/// 账户状态卡片组件
///
/// 显示用户的账户状态和权限信息，包括：
/// - Onboarded 状态
/// - Company Account 状态
/// - Agent 状态
/// - Admin 权限
/// - Super Admin 权限
/// - 最后登录方式
class AccountStatusCard extends StatelessWidget {
  final User user;

  const AccountStatusCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题和描述
            const Text(
              'Account Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Your account information and permissions',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),

            // 账户基本信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    'User ID',
                    '#${user.id}',
                    Icons.fingerprint,
                  ),
                  if (user.slug != null && user.slug!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      'Username',
                      user.slug!,
                      Icons.person_outline,
                    ),
                  ],
                  if (user.stripeCustomerId != null &&
                      user.stripeCustomerId!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      context,
                      'Customer ID',
                      user.stripeCustomerId!,
                      Icons.payment,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 状态信息网格（两列）
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左列
                Expanded(
                  child: Column(
                    children: [
                      _buildStatusRow(context, 'Onboarded', user.isOnboarded),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        context,
                        'Company Account',
                        user.isCompany,
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        context,
                        'Agent Status',
                        user.isAgent,
                        customLabel: user.isAgent ? 'Agent' : 'User',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 右列
                Expanded(
                  child: Column(
                    children: [
                      _buildStatusRow(context, 'Admin', user.isAdmin),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        context,
                        'Super Admin',
                        user.isSuperAdmin,
                      ),
                      const SizedBox(height: 12),
                      _buildTextRow(
                        context,
                        'Last Login',
                        user.lastLoginType ?? 'N/A',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建状态行（带 Yes/No badge）
  Widget _buildStatusRow(
    BuildContext context,
    String label,
    bool status, {
    String? customLabel,
  }) {
    final badgeLabel = customLabel ?? (status ? 'Yes' : 'No');
    final badgeColor = status
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            badgeLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建文本行（用于最后登录方式）
  Widget _buildTextRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建信息行（用于 User ID、Username 等）
  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          SnackBarHelper.showSuccess(
            context,
            title: 'Copied',
            message: '$label copied to clipboard',
          );
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.copy, size: 14, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}
