import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../button.dart';
import '../input.dart';

class CreateProjectImportPublicView extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? errorText;
  final VoidCallback onImport;
  final ValueChanged<String> onChanged;

  const CreateProjectImportPublicView({
    super.key,
    required this.urlController,
    required this.nameController,
    required this.descriptionController,
    required this.errorText,
    required this.onImport,
    required this.onChanged,
  });

  bool _canImport(String url, String name) {
    return url.trim().isNotEmpty && name.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final listenable = Listenable.merge([urlController, nameController]);

    return Column(
      key: const ValueKey('import_public'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.public, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc?.translate('create_project_public_repo_info') ??
                      'We will mirror the public repo into the organization workspace. Large repos may take longer.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Input(
          controller: urlController,
          onChanged: onChanged,
          labelText:
              loc?.translate('create_project_public_repo_url') ??
              'Public Repo URL',
          hintText: 'https://github.com/owner/repo',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.link),
          errorText: (errorText != null && errorText!.isNotEmpty)
              ? errorText
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          loc?.translate('create_project_public_repo_example') ??
              'Example: https://github.com/owner/repo',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 16),
        Input(
          controller: nameController,
          onChanged: onChanged,
          labelText:
              loc?.translate('create_project_project_name') ?? 'Project Name',
          hintText:
              loc?.translate('create_project_project_name_hint') ??
              'my-project',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.folder),
        ),
        const SizedBox(height: 16),
        Input(
          controller: descriptionController,
          onChanged: onChanged,
          labelText:
              loc?.translate('create_project_description') ?? 'Description',
          hintText:
              loc?.translate('optional_description') ?? 'Optional description',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.description),
        ),
        const SizedBox(height: 20),
        ListenableBuilder(
          listenable: listenable,
          builder: (context, _) {
            final enabled = _canImport(urlController.text, nameController.text);
            return SizedBox(
              width: double.infinity,
              child: Button(
                onPressed: enabled ? onImport : null,
                disabled: !enabled,
                variant: ButtonVariant.defaultVariant,
                size: ButtonSize.defaultSize,
                text:
                    loc?.translate('create_project_import_repo_action') ??
                    'Import Repository',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
