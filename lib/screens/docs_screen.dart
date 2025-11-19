import 'package:flutter/material.dart';

class DocsScreen extends StatelessWidget {
  const DocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documentation')),
      body: ListView(
        children: const [
          ListTile(title: Text('Getting Started'), trailing: Icon(Icons.arrow_forward_ios)),
          ListTile(title: Text('API Reference'), trailing: Icon(Icons.arrow_forward_ios)),
          ListTile(title: Text('Architecture'), trailing: Icon(Icons.arrow_forward_ios)),
        ],
      ),
    );
  }
}
