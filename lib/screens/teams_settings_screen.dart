import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/d1vai_service.dart';
import '../widgets/snackbar_helper.dart';
import 'team_detail_screen.dart';

class TeamsSettingsScreen extends StatefulWidget {
  const TeamsSettingsScreen({super.key});

  @override
  State<TeamsSettingsScreen> createState() => _TeamsSettingsScreenState();
}

class _TeamsSettingsScreenState extends State<TeamsSettingsScreen> {
  final D1vaiService _d1vaiService = D1vaiService();
  List<Team> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final teams = await _d1vaiService.getMyTeams();
      if (mounted) {
        setState(() {
          _teams = teams;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load teams: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        SnackBarHelper.showError(
          context,
          title: 'Error',
          message: 'Failed to load teams: $e',
        );
      }
    }
  }

  Future<void> _showCreateTeamDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Team Name *',
                hintText: 'Enter team name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter team description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop({
                  'name': name,
                  'description': descriptionController.text.trim(),
                });
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ).then((result) async {
      if (result == null) return;

      try {
        final newTeam = await _d1vaiService.createTeam(
          result['name'],
          result['description'],
        );
        if (mounted) {
          setState(() {
            _teams.insert(0, newTeam);
          });
          SnackBarHelper.showSuccess(
            context,
            title: 'Success',
            message: 'Team created successfully',
          );
        }
      } catch (e) {
        debugPrint('Failed to create team: $e');
        if (mounted) {
          SnackBarHelper.showError(
            context,
            title: 'Error',
            message: 'Failed to create team: $e',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _teams.isEmpty
              ? _buildEmptyState()
              : _buildTeamsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTeamDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Team'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_work_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No teams yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first team to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final team = _teams[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                team.name.isNotEmpty ? team.name[0].toUpperCase() : 'T',
                style: TextStyle(
                  color: Colors.deepPurple.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              team.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (team.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    team.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${team.memberCount} ${team.memberCount == 1 ? 'member' : 'members'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TeamDetailScreen(team: team),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
