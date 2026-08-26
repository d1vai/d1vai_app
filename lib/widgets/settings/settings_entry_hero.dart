import 'package:flutter/material.dart';

/// Shared visual identity for settings entries and their destination app bars.
class SettingsEntryHero extends StatelessWidget {
  static const notificationsTag = 'settings-entry-notifications';
  static const accountDataTag = 'settings-entry-account-data';
  static const developerTag = 'settings-entry-developer';
  static const helpSupportTag = 'settings-entry-help-support';

  final String tag;
  final IconData icon;
  final Color color;
  final double size;

  const SettingsEntryHero({
    super.key,
    required this.tag,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) => Hero(
    tag: tag,
    child: Icon(icon, color: color, size: size),
  );
}
