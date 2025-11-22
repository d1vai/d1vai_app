import 'package:flutter/material.dart';
import '../services/github_service.dart';
import 'snackbar_helper.dart';

class ImportRepositoryDialog extends StatefulWidget {
  final Map<String, dynamic> repository;

  const ImportRepositoryDialog({
    super.key,
    required this.repository,
  });

  @override
  State<ImportRepositoryDialog> createState() => _ImportRepositoryDialogState();
}

class _ImportRepositoryDialogState extends State<ImportRepositoryDialog> {
  final GitHubService _githubService = GitHubService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _projectNameController;
  late TextEditingController _projectDescriptionController;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with repository information
    final repoName = widget.repository['name'] ?? '';
    final repoDescription = widget.repository['description'] ?? '';

    _projectNameController = TextEditingController(text: repoName);
    _projectDescriptionController = TextEditingController(
      text: repoDescription.isEmpty
        ? 'Imported from GitHub: ${widget.repository['full_name'] ?? repoName}'
        : repoDescription,
    );
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      final repositoryFullName = widget.repository['full_name'] ?? '';
      final defaultBranch = widget.repository['default_branch'] ?? 'main';

      await _githubService.importProjectFromGitHub(
        repositoryFullName: repositoryFullName,
        projectName: _projectNameController.text.trim(),
        projectDescription: _projectDescriptionController.text.trim(),
        branch: defaultBranch,
      );

      if (!mounted) return;

      SnackBarHelper.showSuccess(
        context,
        title: 'Success',
        message: 'Project imported successfully!',
      );

      // Close dialog and return success
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      SnackBarHelper.showError(
        context,
        title: 'Import Failed',
        message: 'Failed to import repository: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repoName = widget.repository['name'] ?? '';
    final repoFullName = widget.repository['full_name'] ?? '';
    final language = widget.repository['language'];
    final stars = widget.repository['stargazers_count'] ?? 0;
    final isPrivate = widget.repository['private'] ?? false;

    return AlertDialog(
      title: const Text('Import Repository'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Repository Info Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPrivate ? Icons.lock : Icons.folder,
                            size: 20,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              repoFullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isPrivate)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Private',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (language != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                language,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.deepPurple.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$stars',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Project Name Input
                TextFormField(
                  controller: _projectNameController,
                  decoration: const InputDecoration(
                    labelText: 'Project Name *',
                    hintText: 'Enter project name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Project name is required';
                    }
                    return null;
                  },
                  enabled: !_isImporting,
                ),
                const SizedBox(height: 16),

                // Project Description Input
                TextFormField(
                  controller: _projectDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Project Description',
                    hintText: 'Enter project description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  enabled: !_isImporting,
                ),
                const SizedBox(height: 8),

                // Info Text
                Text(
                  'This will create a new project from the repository: $repoName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isImporting ? null : _handleImport,
          icon: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.download),
          label: Text(_isImporting ? 'Importing...' : 'Import'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
