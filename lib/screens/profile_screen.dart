import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: user?.picture != null && user!.picture.isNotEmpty 
                ? NetworkImage(user.picture) 
                : null,
            child: user?.picture == null || user!.picture.isEmpty 
                ? const Icon(Icons.person, size: 50) 
                : null,
          ),
          const SizedBox(height: 16),
          ListTile(title: const Text('Name'), subtitle: Text(user?.companyName ?? 'N/A')),
          ListTile(title: const Text('Email'), subtitle: Text(user?.email ?? 'N/A')),
          ListTile(title: const Text('Industry'), subtitle: Text(user?.industry ?? 'N/A')),
        ],
      ),
    );
  }
}
