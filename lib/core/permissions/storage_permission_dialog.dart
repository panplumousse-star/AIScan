import 'package:flutter/material.dart';

/// Shows a dialog prompting the user to open app settings to grant storage permission.
///
/// This dialog is shown when storage permission has been denied and the user
/// cannot grant it through the normal permission flow. It provides a clear
/// explanation of why storage access is needed and offers to open settings.
///
/// Returns `true` if the user chose to open settings, `false` otherwise.
///
/// ## Usage
/// ```dart
/// if (await permissionService.isPermissionBlocked()) {
///   final shouldOpenSettings = await showStorageSettingsDialog(context);
///   if (shouldOpenSettings) {
///     await permissionService.openSettings();
///   }
/// }
/// ```
Future<bool> showStorageSettingsDialog(BuildContext context) async {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.folder_outlined,
        size: 48,
        color: colorScheme.primary,
      ),
      title: const Text('Storage Permission Required'),
      content: const Text(
        'To share documents, Scanaï needs access to storage. '
        'Please enable storage permission in Settings.\n\n'
        'Would you like to open Settings now?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// Shows a snackbar indicating that storage permission was denied.
///
/// This is a simple notification to inform the user that the share action
/// could not be completed due to missing storage permission.
///
/// ## Usage
/// ```dart
/// final state = await permissionService.requestSystemPermission();
/// if (state != StoragePermissionState.granted) {
///   showStoragePermissionDeniedSnackbar(context);
/// }
/// ```
void showStoragePermissionDeniedSnackbar(
  BuildContext context, {
  VoidCallback? onOpenSettings,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Storage permission is required to share documents'),
      action: onOpenSettings != null
          ? SnackBarAction(
              label: 'Settings',
              onPressed: onOpenSettings,
            )
          : null,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Shows a snackbar indicating that sharing failed due to an error.
///
/// Use this when an unexpected error occurs during the share process,
/// not for permission-related issues.
///
/// ## Usage
/// ```dart
/// try {
///   await shareService.shareDocument(document);
/// } on Object catch (e) {
///   showShareErrorSnackbar(context, e.toString());
/// }
/// ```
void showShareErrorSnackbar(
  BuildContext context,
  String errorMessage, {
  VoidCallback? onRetry,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Failed to share: $errorMessage'),
      action: onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              onPressed: onRetry,
            )
          : null,
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Shows a snackbar indicating that a document file was not found.
///
/// Use this when attempting to share a document whose file no longer exists.
///
/// ## Usage
/// ```dart
/// if (!await documentFile.exists()) {
///   showDocumentNotFoundSnackbar(context);
///   return;
/// }
/// ```
void showDocumentNotFoundSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Document file not found. It may have been deleted.'),
      duration: Duration(seconds: 4),
    ),
  );
}

/// Shows a snackbar indicating that document decryption failed.
///
/// Use this when a document cannot be decrypted for sharing.
///
/// ## Usage
/// ```dart
/// try {
///   await repository.getDecryptedFilePath(document);
/// } on DocumentRepositoryException {
///   showDecryptionFailedSnackbar(context);
/// }
/// ```
void showDecryptionFailedSnackbar(
  BuildContext context, {
  VoidCallback? onRetry,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(
        'Failed to prepare document for sharing. Please try again.',
      ),
      action: onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              onPressed: onRetry,
            )
          : null,
      duration: const Duration(seconds: 4),
    ),
  );
}
