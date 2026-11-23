import 'package:flutter/material.dart';
import '../services/app_update_service.dart';

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo update,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final notes = update.releaseNotes.isEmpty
      ? 'Bug fixes and improvements.'
      : update.releaseNotes;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Article Pulse update available'),
      content: SingleChildScrollView(
        child: Text(
          'Version ${update.versionLabel} is ready to install.\n\n'
          '$notes\n\n'
          'Android will ask you to confirm the installation.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download & Install'),
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Downloading Article Pulse update...')),
            );
            try {
              await AppUpdateService().downloadAndInstall(update);
              messenger.hideCurrentSnackBar();
            } catch (error) {
              messenger.hideCurrentSnackBar();
              messenger.showSnackBar(
                SnackBar(content: Text('Update failed: $error')),
              );
            }
          },
        ),
      ],
    ),
  );
}
