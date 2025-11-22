import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/snackbar_helper.dart';
import '../services/d1vai_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Settings'),
      ),
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
                          Icon(Icons.wallet, color: Colors.deepPurple, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Connect Your Wallet',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Connect your wallet to receive payments and rewards',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
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
              _buildWalletCard(
                WalletType.solana,
                user?.solWallet,
              ),
              const SizedBox(height: 12),

              // SUI Wallet Card
              _buildWalletCard(
                WalletType.sui,
                user?.suiWallet,
              ),
              const SizedBox(height: 12),

              // Ethereum Wallet Card (Coming Soon)
              _buildWalletCard(
                WalletType.evm,
                null,
                isComingSoon: true,
              ),
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
    final bool isConnected = currentAddress != null && currentAddress.isNotEmpty;

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
              child: Icon(
                walletType.icon,
                color: walletType.color,
                size: 28,
              ),
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
                  Text(
                    isConnected
                        ? '${walletType.symbol} • ${_formatAddress(currentAddress)}'
                        : isComingSoon
                            ? 'Coming Soon'
                            : 'Not connected',
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
          content: Text('Are you sure you want to disconnect your ${walletType.name} wallet?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Disconnect', style: TextStyle(color: Colors.white)),
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
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect ${walletType.name} Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To connect your ${walletType.name} wallet:'),
            const SizedBox(height: 12),
            Text(
              '1. Make sure you have ${walletType.name} wallet installed',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '2. Click "Continue" to connect your wallet',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '3. Approve the connection in your wallet app',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: This is a demo implementation. In production, integrate with actual wallet SDK.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _simulateWalletConnection(walletType);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateWalletConnection(WalletType walletType) async {
    setState(() {
      _isBinding = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      // Simulate wallet connection delay
      await Future.delayed(const Duration(seconds: 2));

      // Generate a mock wallet address based on wallet type
      final mockAddress = _generateMockWalletAddress(walletType);

      // Update user profile
      await _d1vaiService.putUserProfile({
        if (walletType == WalletType.solana) 'sol_wallet': mockAddress,
        if (walletType == WalletType.sui) 'sui_wallet': mockAddress,
      });

      // Refresh user data
      await authProvider.fetchUser();

      if (!mounted) return;
      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: '${walletType.name} wallet connected successfully',
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Failed to connect wallet: $e',
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

  String _generateMockWalletAddress(WalletType walletType) {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();

    switch (walletType) {
      case WalletType.solana:
        // Solana addresses are typically 32-44 characters
        buffer.write('A');
        for (int i = 0; i < 43; i++) {
          buffer.write(chars.codeUnitAt(i % chars.length));
        }
        break;
      case WalletType.sui:
        // SUI addresses start with 0x and are 64 characters
        buffer.write('0x');
        for (int i = 0; i < 62; i++) {
          buffer.write(chars.codeUnitAt(i % chars.length));
        }
        break;
      case WalletType.evm:
        // Ethereum addresses start with 0x and are 40 characters
        buffer.write('0x');
        for (int i = 0; i < 40; i++) {
          buffer.write(chars.codeUnitAt(i % chars.length));
        }
        break;
    }

    return buffer.toString();
  }
}
