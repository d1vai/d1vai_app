import 'package:flutter/material.dart';

class LoginLegalLinks extends StatelessWidget {
  final String agreementText;
  final String legalLabel;
  final VoidCallback onOpenLegal;

  const LoginLegalLinks({
    super.key,
    required this.agreementText,
    required this.legalLabel,
    required this.onOpenLegal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          agreementText,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: onOpenLegal,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(legalLabel),
        ),
      ],
    );
  }
}
