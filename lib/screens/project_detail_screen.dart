import 'package:flutter/material.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Project $projectId'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Deployments'),
              Tab(text: 'Settings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(),
            _buildDeploymentsTab(),
            _buildSettingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return const Center(child: Text('Project Overview Content'));
  }

  Widget _buildDeploymentsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_done, color: Colors.green),
            title: Text('Deployment #${100 - index}'),
            subtitle: const Text('Deployed 2 hours ago'),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Enable Analytics'),
          value: true,
          onChanged: (val) {},
        ),
        SwitchListTile(
          title: const Text('Public Access'),
          value: false,
          onChanged: (val) {},
        ),
        const Divider(),
        ListTile(
          title: const Text('Delete Project', style: TextStyle(color: Colors.red)),
          leading: const Icon(Icons.delete, color: Colors.red),
          onTap: () {},
        ),
      ],
    );
  }
}
