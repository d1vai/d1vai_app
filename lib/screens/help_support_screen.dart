import 'package:flutter/material.dart';

import 'docs_screen.dart';

/// Help and support is the documentation catalog plus a single support CTA.
/// Keeping this wrapper preserves the existing route and settings entry point.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) => const DocsScreen(showSupportCta: true);
}
