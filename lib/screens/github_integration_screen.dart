import 'package:flutter/material.dart';

import 'settings_screen.dart';

class GitHubIntegrationScreen extends StatelessWidget {
  const GitHubIntegrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen(initialTab: 'github');
  }
}
