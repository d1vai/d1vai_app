import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/snackbar_helper.dart';

class GithubSettingsScreen extends StatefulWidget {
  const GithubSettingsScreen({super.key});

  @override
  State<GithubSettingsScreen> createState() => _GithubSettingsScreenState();
}

class _GithubSettingsScreenState extends State<GithubSettingsScreen> {
  final TextEditingController _tokenController = TextEditingController();

  bool _isConnecting = false;
  bool _isTokenLoaded = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('github_token') ?? '';
      if (token.isNotEmpty) {
        _tokenController.text = token;
        setState(() {
          _isConnected = true;
          _isTokenLoaded = true;
        });
      } else {
        setState(() {
          _isTokenLoaded = true;
        });
      }
    } catch (e) {
      setState(() {
        _isTokenLoaded = true;
      });
    }
  }

  Future<void> _connectGithub() async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      SnackBarHelper.showError(
        context,
        title: 'Error',
        message: 'Please enter a GitHub token',
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // 验证 Token（调用 API 验证）
      // 目前先用模拟验证，未来可以调用真实 API
      await Future.delayed(const Duration(seconds: 1));

      // 保存 Token 到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('github_token', token);

      setState(() {
        _isConnected = true;
      });

      if (mounted) {
        SnackBarHelper.showSuccess(
          context,
          title: 'Success',
          message: 'GitHub account connected successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Failed to connect GitHub: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnectGithub() async {
    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect GitHub'),
        content: const Text('Are you sure you want to disconnect your GitHub account?'),
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
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('github_token');

        setState(() {
          _isConnected = false;
          _tokenController.clear();
        });

        if (mounted) {
          SnackBarHelper.showSuccess(
            context,
            title: 'Success',
            message: 'GitHub account disconnected',
          );
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to disconnect: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTokenLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub Integration'),
      ),
      body: ListView(
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
                        Icons.code,
                        color: Colors.deepPurple,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isConnected ? 'Connected' : 'Not Connected',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isConnected ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isConnected
                                  ? 'Your GitHub account is connected'
                                  : 'Connect your GitHub account to import projects',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
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
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GitHub Token',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your GitHub Personal Access Token with the following permissions:',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      children: [
                        Text('• repo (Full control of private repositories)'),
                        SizedBox(height: 4),
                        Text('• read:user (Read user profile data)'),
                        SizedBox(height: 4),
                        Text('• user:email (Access user email addresses)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tokenController,
                    enabled: !_isConnecting,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'GitHub Token',
                      hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _connectGithub,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_isConnected ? Icons.refresh : Icons.link),
                      label: Text(
                        _isConnecting
                            ? 'Connecting...'
                            : _isConnected
                                ? 'Update Token'
                                : 'Connect GitHub',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (_isConnected) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isConnecting ? null : _disconnectGithub,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to create a GitHub Token',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1. Go to GitHub Settings > Developer settings > Personal access tokens\n'
                    '2. Click "Generate new token (classic)"\n'
                    '3. Select the required scopes (repo, read:user, user:email)\n'
                    '4. Click "Generate token"\n'
                    '5. Copy the token and paste it above',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }
}
