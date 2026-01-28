import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../widgets/login_required_view.dart';

class ChatPlaygroundScreen extends StatefulWidget {
  const ChatPlaygroundScreen({super.key});

  @override
  State<ChatPlaygroundScreen> createState() => _ChatPlaygroundScreenState();
}

class _ChatPlaygroundScreenState extends State<ChatPlaygroundScreen> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<ProjectProvider>();

    if (!auth.isAuthenticated) {
      return const Scaffold(
        body: LoginRequiredView(
          message: 'Please login first to use Chat.',
        ),
      );
    }

    final q = _searchController.text.trim().toLowerCase();
    final projects = q.isEmpty
        ? provider.projects
        : provider.projects.where((p) {
            return p.projectName.toLowerCase().contains(q) ||
                p.projectDescription.toLowerCase().contains(q) ||
                p.tags.join(' ').toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Playground'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => provider.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _promptController,
              decoration: const InputDecoration(
                hintText: 'Optional: start with a prompt…',
                prefixIcon: Icon(Icons.auto_awesome),
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              minLines: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search projects…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: provider.isInitialLoading
                ? const Center(child: CircularProgressIndicator())
                : projects.isEmpty
                ? const Center(child: Text('No projects found'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: projects.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = projects[index];
                      return Card(
                        child: ListTile(
                          leading: Text(
                            (p.emoji ?? '💬'),
                            style: const TextStyle(fontSize: 20),
                          ),
                          title: Text(
                            p.projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            p.projectDescription,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            final prompt = _promptController.text.trim();
                            final qp = prompt.isEmpty
                                ? ''
                                : '?autoprompt=${Uri.encodeQueryComponent(prompt)}';
                            context.go('/projects/${p.id}/chat$qp');
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

