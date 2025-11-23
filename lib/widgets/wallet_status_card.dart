import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import 'snackbar_helper.dart';

/// 钱包状态卡片组件
///
/// 显示用户已绑定的区块链钱包地址，包括：
/// - Solana (SOL) 钱包
/// - SUI 钱包
/// - EVM (Ethereum) 钱包
class WalletStatusCard extends StatelessWidget {
  final User user;

  const WalletStatusCard({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final hasSolWallet = user.solWallet.isNotEmpty;
    final hasSuiWallet = user.suiWallet.isNotEmpty;
    final hasEvmWallet = user.evmWallet.isNotEmpty;
    final hasAnyWallet = hasSolWallet || hasSuiWallet || hasEvmWallet;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.deepPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wallet Connections',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAnyWallet
                            ? 'Your connected blockchain wallets'
                            : 'Connect wallets on web to enable blockchain features',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 钱包列表
            _buildWalletItem(
              context,
              walletType: 'sol',
              name: 'Solana',
              symbol: 'SOL',
              address: user.solWallet,
              gradientColors: [Colors.purple, Colors.pink],
            ),
            const SizedBox(height: 12),
            _buildWalletItem(
              context,
              walletType: 'sui',
              name: 'SUI',
              symbol: 'SUI',
              address: user.suiWallet,
              gradientColors: [Colors.blue, Colors.cyan],
            ),
            const SizedBox(height: 12),
            _buildWalletItem(
              context,
              walletType: 'evm',
              name: 'Ethereum',
              symbol: 'ETH',
              address: user.evmWallet,
              gradientColors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerHighest,
              ],
            ),

            // 提示信息
            if (!hasAnyWallet) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Visit d1v.ai on web to connect your crypto wallets',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建单个钱包项
  Widget _buildWalletItem(
    BuildContext context, {
    required String walletType,
    required String name,
    required String symbol,
    required String address,
    required List<Color> gradientColors,
  }) {
    final isConnected = address.isNotEmpty;
    final displayAddress = isConnected
        ? '${address.substring(0, 8)}...${address.substring(address.length - 6)}'
        : 'Not connected';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected ? Colors.green.shade200 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 钱包图标
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 钱包信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name Wallet',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayAddress,
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnected
                        ? Colors.grey.shade700
                        : Colors.grey.shade500,
                    fontFamily: isConnected ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),

          // 状态标签/复制按钮
          if (isConnected)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: address));
                    if (context.mounted) {
                      SnackBarHelper.showSuccess(
                        context,
                        title: 'Copied',
                        message: '$name wallet address copied',
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Not linked',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
