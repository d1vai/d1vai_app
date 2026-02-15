import 'package:flutter/material.dart';

class LoginLegalLinks extends StatelessWidget {
  final String agreementText;
  final String privacyLabel;
  final String legalLabel;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenLegal;

  const LoginLegalLinks({
    super.key,
    required this.agreementText,
    required this.privacyLabel,
    required this.legalLabel,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    required this.onOpenLegal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          agreementText,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            TextButton(onPressed: onOpenTerms, child: const Text('Terms')),
            const Text('·', style: TextStyle(color: Colors.grey)),
            TextButton(onPressed: onOpenPrivacy, child: Text(privacyLabel)),
            const Text('·', style: TextStyle(color: Colors.grey)),
            TextButton(onPressed: onOpenLegal, child: Text(legalLabel)),
          ],
        ),
      ],
    );
  }
}
