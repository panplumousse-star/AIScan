import 'package:flutter/material.dart';

// ============================================================================
// Permission Dialog Result
// ============================================================================

/// Result of the camera permission dialog.
///
/// This enum represents the possible user choices from the camera permission
/// dialog. It is kept for potential future use, but the 3-option dialog that
/// uses it is deprecated.
///
/// See also:
/// - [showCameraSettingsDialog] - the recommended Yes/No dialog for blocked permissions
enum PermissionDialogResult {
  /// User denied camera permission.
  denied,

  /// User granted camera permission for this session only.
  sessionOnly,

  /// User fully granted camera permission.
  granted,
}

// ============================================================================
// Deprecated 3-Option Permission Dialog
// ============================================================================

/// Shows a camera permission dialog with three options: Deny, This Session, Accept.
///
/// **DEPRECATED**: This dialog should not be used. The native Android permission
/// dialog should be shown first via [CameraPermissionService.requestSystemPermission()].
/// For blocked permissions, use [showCameraSettingsDialog] instead.
///
/// This function is kept for backward compatibility but will be removed in a
/// future release. The new permission flow is:
/// 1. Show native Android dialog first (via permission_handler)
/// 2. If permission is blocked, show [showCameraSettingsDialog] to redirect to settings
///
/// Parameters:
/// - [context]: The build context for showing the dialog.
///
/// Returns a [PermissionDialogResult] or `null` if the dialog was dismissed.
@Deprecated(
  'Use CameraPermissionService.requestSystemPermission() for first-time requests, '
  'and showCameraSettingsDialog() for blocked permissions. '
  'This dialog will be removed in a future release.',
)
Future<PermissionDialogResult?> showCameraPermissionDialog(
  BuildContext context,
) async {
  return showDialog<PermissionDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _CameraPermissionDialog(),
  );
}

/// A dialog widget that shows three permission options: Deny, This Session, Accept.
///
/// **DEPRECATED**: This dialog should not be used. See [showCameraPermissionDialog]
/// for details on the new permission flow.
@Deprecated(
  'This dialog is deprecated. Use the native Android permission dialog for '
  'first-time requests, and showCameraSettingsDialog() for blocked permissions.',
)
class _CameraPermissionDialog extends StatelessWidget {
  const _CameraPermissionDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.camera_alt_outlined,
        size: 48,
        color: colorScheme.primary,
      ),
      title: const Text('Camera Permission'),
      content: const Text(
        'AIScan needs camera access to scan documents. '
        'Please choose how you would like to grant permission.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(PermissionDialogResult.denied),
          child: Text(
            'Deny',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(PermissionDialogResult.sessionOnly),
          child: const Text('This Session'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(PermissionDialogResult.granted),
          child: const Text('Accept'),
        ),
      ],
    );
  }
}

// ============================================================================
// Settings Redirect Dialog
// ============================================================================

/// Shows a Yes/No dialog for redirecting to system settings when camera
/// permission is blocked.
///
/// This dialog should be shown when:
/// - The user has previously denied camera permission
/// - The permission is permanently denied ("Don't ask again" selected)
/// - A temporary "Only this time" permission has expired
///
/// The dialog asks the user if they want to open system settings to enable
/// camera access manually.
///
/// Parameters:
/// - [context]: The build context for showing the dialog.
///
/// Returns `true` if the user taps "Open Settings", `false` if the user
/// taps "Not Now" (dismiss), or `null` if the dialog is dismissed by tapping outside.
///
/// ## Usage
/// ```dart
/// final permissionService = ref.read(cameraPermissionServiceProvider);
///
/// if (await permissionService.isPermissionBlocked()) {
///   final shouldOpenSettings = await showCameraSettingsDialog(context);
///   if (shouldOpenSettings == true) {
///     await permissionService.openSettings();
///   }
/// }
/// ```
Future<bool?> showCameraSettingsDialog(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => const _CameraSettingsDialog(),
  );
}

/// Dialog widget that asks the user if they want to open settings.
class _CameraSettingsDialog extends StatelessWidget {
  const _CameraSettingsDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.settings_outlined,
        size: 48,
        color: colorScheme.secondary,
      ),
      title: const Text('Camera Access Required'),
      content: const Text(
        'Camera permission is required to scan documents. '
        'Would you like to open Settings to enable camera access?',
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
