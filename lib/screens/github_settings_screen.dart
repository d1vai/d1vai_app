import 'package:flutter/material.dart';

import 'settings_screen.dart';

class GithubSettingsScreen extends StatelessWidget {
  const GithubSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen(initialTab: 'github');
  }
}
