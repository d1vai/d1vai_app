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
    return Column(
      children: [
        Text(
          agreementText,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        TextButton(onPressed: onOpenLegal, child: Text(legalLabel)),
      ],
    );
  }
}
