import 'package:flutter/material.dart';

// ============================================================================
// Settings Redirect Dialog
// ============================================================================

/// Shows a Yes/No dialog for redirecting to system settings when contact
/// permission is blocked.
///
/// This dialog should be shown when:
/// - The user has previously denied contact permission
/// - The permission is permanently denied ("Don't ask again" selected)
/// - A temporary "Only this time" permission has expired
///
/// The dialog asks the user if they want to open system settings to enable
/// contact access manually.
///
/// Parameters:
/// - [context]: The build context for showing the dialog.
///
/// Returns `true` if the user taps "Open Settings", `false` if the user
/// taps "Not Now" (dismiss), or `null` if the dialog is dismissed by tapping outside.
///
/// ## Usage
/// ```dart
/// final permissionService = ref.read(contactPermissionServiceProvider);
///
/// if (await permissionService.isPermissionBlocked()) {
///   final shouldOpenSettings = await showContactSettingsDialog(context);
///   if (shouldOpenSettings == true) {
///     await permissionService.openSettings();
///   }
/// }
/// ```
Future<bool?> showContactSettingsDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _ContactSettingsDialog(),
  );
}

/// Dialog widget that asks the user if they want to open settings for contacts.
class _ContactSettingsDialog extends StatelessWidget {
  const _ContactSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.contacts_outlined,
        size: 48,
        color: colorScheme.secondary,
      ),
      title: const Text('Contact Access Required'),
      content: const Text(
        'Contact permission is required to save extracted information as a new contact. '
        'Would you like to open Settings to enable contact access?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}

// ============================================================================
// Snackbars
// ============================================================================

/// Shows a snackbar when contact permission is denied.
///
/// This is a non-intrusive notification to inform the user that the
/// contact creation was cancelled due to permission denial.
void showContactPermissionDeniedSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Contact permission denied. Cannot create contact.'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ),
  );
}

/// Shows a snackbar when contact creation fails.
///
/// Parameters:
/// - [context]: The build context
/// - [onRetry]: Optional callback to retry the operation
void showContactCreationErrorSnackbar(
  BuildContext context, {
  VoidCallback? onRetry,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Failed to create contact. Please try again.'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              onPressed: onRetry,
            )
          : null,
    ),
  );
}

/// Shows a snackbar when contact is created successfully.
///
/// Parameters:
/// - [context]: The build context
/// - [contactName]: The name of the created contact
void showContactCreatedSnackbar(BuildContext context, String contactName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Contact "$contactName" created successfully'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Shows a snackbar when no contact data is found in the document.
void showNoContactDataFoundSnackbar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No contact information found in this document.'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ),
  );
}
