import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/snackbar_helper.dart';
import '../services/d1vai_service.dart';
import '../utils/error_utils.dart';

enum WalletType {
  solana('Solana', 'SOL', Icons.currency_bitcoin, Colors.purple),
  sui('SUI', 'SUI', Icons.diamond, Colors.blue),
  evm('Ethereum', 'ETH', Icons.attach_money, Colors.grey);

  const WalletType(this.name, this.symbol, this.icon, this.color);
  final String name;
  final String symbol;
  final IconData icon;
  final Color color;
}

class WalletSettingsScreen extends StatefulWidget {
  const WalletSettingsScreen({super.key});

  @override
  State<WalletSettingsScreen> createState() => _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends State<WalletSettingsScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  bool _isBinding = false;

  String _signMessage(WalletType walletType, String address) {
    return 'Sign in to d1vai\\n'
        'wallet=$address\\n'
        'chain=${walletType.symbol}\\n'
        'nonce=${DateTime.now().millisecondsSinceEpoch}\\n'
        'This signature does NOT trigger any on-chain transaction.';
  }

  String? _validateWalletAddress(WalletType walletType, String address) {
    final a = address.trim();
    if (a.isEmpty) return 'Please enter a wallet address';

    switch (walletType) {
      case WalletType.solana:
        if (a.length < 32 || a.length > 44) {
          return 'Solana address should be 32–44 characters';
        }
        if (a.contains(RegExp(r'\\s'))) return 'Address contains whitespace';
        break;
      case WalletType.sui:
        if (!a.startsWith('0x')) return 'SUI address should start with 0x';
        if (a.length != 66)
          return 'SUI address should be 66 characters (0x + 64 hex)';
        break;
      case WalletType.evm:
        if (!a.startsWith('0x')) return 'EVM address should start with 0x';
        if (a.length != 42)
          return 'EVM address should be 42 characters (0x + 40 hex)';
        break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Settings')),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.wallet,
                            color: Colors.deepPurple,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connect Your Wallet',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Connect your wallet to receive payments and rewards',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Solana Wallet Card
              _buildWalletCard(WalletType.solana, user?.solWallet),
              const SizedBox(height: 12),

              // SUI Wallet Card
              _buildWalletCard(WalletType.sui, user?.suiWallet),
              const SizedBox(height: 12),

              // Ethereum Wallet Card (Coming Soon)
              _buildWalletCard(WalletType.evm, null, isComingSoon: true),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWalletCard(
    WalletType walletType,
    String? currentAddress, {
    bool isComingSoon = false,
  }) {
    final bool isConnected =
        currentAddress != null && currentAddress.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: walletType.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(walletType.icon, color: walletType.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    walletType.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isConnected)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${walletType.symbol} • ${_formatAddress(currentAddress)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy address',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () async {
                            final raw = currentAddress.trim();
                            if (raw.isEmpty) return;
                            await Clipboard.setData(ClipboardData(text: raw));
                            if (!mounted) return;
                            SnackBarHelper.showSuccess(
                              context,
                              title: 'Copied',
                              message: '${walletType.name} address copied',
                            );
                          },
                        ),
                      ],
                    )
                  else
                    Text(
                      isComingSoon ? 'Coming Soon' : 'Not connected',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isComingSoon || _isBinding
                  ? null
                  : () => _handleWalletAction(walletType),
              style: ElevatedButton.styleFrom(
                backgroundColor: isConnected
                    ? Colors.grey.shade200
                    : walletType.color,
                foregroundColor: isConnected ? Colors.black87 : Colors.white,
              ),
              child: _isBinding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      isConnected ? 'Disconnect' : 'Connect',
                      style: const TextStyle(fontSize: 13),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.length <= 8) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Future<void> _handleWalletAction(WalletType walletType) async {
    if (_isBinding) return;

    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please login first',
      );
      return;
    }

    // Check if already connected
    bool isConnected = false;
    String? currentAddress;

    switch (walletType) {
      case WalletType.solana:
        currentAddress = user.solWallet;
        break;
      case WalletType.sui:
        currentAddress = user.suiWallet;
        break;
      case WalletType.evm:
        currentAddress = null;
        break;
    }

    isConnected = currentAddress != null && currentAddress.isNotEmpty;

    if (isConnected) {
      // Show disconnect confirmation
      final shouldDisconnect = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disconnect Wallet'),
          content: Text(
            'Are you sure you want to disconnect your ${walletType.name} wallet?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Disconnect',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (shouldDisconnect == true) {
        await _disconnectWallet(walletType);
      }
    } else {
      // Show connect instructions
      await _showConnectDialog(walletType);
    }
  }

  Future<void> _showConnectDialog(WalletType walletType) async {
    final controller = TextEditingController();
    String? error;
    String? address;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final baseMessage = _signMessage(walletType, '<address>');
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return AlertDialog(
              title: Text('Connect ${walletType.name}'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You will sign a message to prove wallet ownership. This does NOT send any funds.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: '${walletType.name} address',
                        hintText: walletType == WalletType.solana
                            ? 'Base58 address'
                            : '0x…',
                        errorText: error,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        baseMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final addr = controller.text.trim();
                    final toCopy = _signMessage(
                      walletType,
                      addr.isEmpty ? '<address>' : addr,
                    );
                    await Clipboard.setData(ClipboardData(text: toCopy));
                    if (!ctx.mounted) return;
                    SnackBarHelper.showSuccess(
                      ctx,
                      title: 'Copied',
                      message: 'Signing message copied',
                    );
                  },
                  child: const Text('Copy message'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final addr = controller.text.trim();
                    final err = _validateWalletAddress(walletType, addr);
                    if (err != null) {
                      setInner(() => error = err);
                      return;
                    }
                    address = addr;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Sign & Connect'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (!mounted) return;
    final addr = address?.trim();
    if (addr == null || addr.isEmpty) return;
    await _connectWallet(walletType, addr);
  }

  Future<void> _connectWallet(WalletType walletType, String address) async {
    setState(() {
      _isBinding = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Persist address binding (signature verification should be implemented server-side).
      await _d1vaiService.putUserProfile({
        if (walletType == WalletType.solana) 'sol_wallet': address,
        if (walletType == WalletType.sui) 'sui_wallet': address,
      });

      // Refresh user data
      await authProvider.fetchUser();

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: '${walletType.name} wallet connected',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: humanizeError(e),
        actionLabel: 'Retry',
        onActionPressed: () {
          if (_isBinding) return;
          unawaited(_showConnectDialog(walletType));
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBinding = false;
        });
      }
    }
  }

  Future<void> _disconnectWallet(WalletType walletType) async {
    setState(() {
      _isBinding = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Update user profile to remove wallet address
      await _d1vaiService.putUserProfile({
        if (walletType == WalletType.solana) 'sol_wallet': '',
        if (walletType == WalletType.sui) 'sui_wallet': '',
      });

      // Refresh user data
      await authProvider.fetchUser();

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: '${walletType.name} wallet disconnected',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to disconnect wallet: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBinding = false;
        });
      }
    }
  }

  // Note: users provide their address in the connect flow.
}
