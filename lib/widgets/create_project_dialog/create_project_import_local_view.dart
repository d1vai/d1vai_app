import 'package:flutter/material.dart';

import '../button.dart';
import '../input.dart';

class CreateProjectImportLocalView extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String? archiveFileName;
  final bool isPrivate;
  final String? errorText;
  final VoidCallback onPickArchive;
  final ValueChanged<bool> onPrivateChanged;
  final VoidCallback onImport;
  final ValueChanged<String> onChanged;

  const CreateProjectImportLocalView({
    super.key,
    required this.nameController,
    required this.descriptionController,
    required this.archiveFileName,
    required this.isPrivate,
    required this.errorText,
    required this.onPickArchive,
    required this.onPrivateChanged,
    required this.onImport,
    required this.onChanged,
  });

  bool _canImport(String name, String? archiveName) {
    return name.trim().isNotEmpty &&
        archiveName != null &&
        archiveName.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listenable = Listenable.merge([
      nameController,
      descriptionController,
    ]);

    return Column(
      key: const ValueKey('import_local'),
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
              Icon(Icons.archive_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upload a local .zip workspace and import it directly as a project. The archive should contain your project files at the root.',
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
          controller: nameController,
          onChanged: onChanged,
          labelText: 'Project Name',
          hintText: 'my-project',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.folder_outlined),
          errorText: (errorText != null && errorText!.isNotEmpty)
              ? errorText
              : null,
        ),
        const SizedBox(height: 16),
        Input(
          controller: descriptionController,
          onChanged: onChanged,
          labelText: 'Description',
          hintText: 'Optional description',
          variant: InputVariant.outlined,
          prefixIcon: const Icon(Icons.description_outlined),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: onPickArchive,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.upload_file, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    archiveFileName?.trim().isNotEmpty == true
                        ? archiveFileName!
                        : 'Choose .zip archive',
                    style: TextStyle(
                      fontSize: 13,
                      color: archiveFileName?.trim().isNotEmpty == true
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onPickArchive,
                  child: const Text('Browse'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Supported format: .zip',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: isPrivate,
          onChanged: onPrivateChanged,
          title: const Text('Private project'),
          subtitle: const Text('Keep the imported project private by default'),
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: listenable,
          builder: (context, _) {
            final enabled = _canImport(nameController.text, archiveFileName);
            return SizedBox(
              width: double.infinity,
              child: Button(
                onPressed: enabled ? onImport : null,
                disabled: !enabled,
                variant: ButtonVariant.defaultVariant,
                size: ButtonSize.defaultSize,
                text: 'Import Local Zip',
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
