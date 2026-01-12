import 'package:flutter/material.dart';

// ============================================================================
// Permission Dialog Result
// ============================================================================

/// The result of the camera permission dialog.
///
/// Used to determine how the user responded to the permission request.
enum PermissionDialogResult {
  /// User denied camera permission.
  ///
  /// The app should not access the camera and should show
  /// an appropriate message explaining why the scanner is unavailable.
  denied,

  /// User granted camera permission permanently.
  ///
  /// This choice should be persisted across app restarts.
  granted,

  /// User granted camera permission for the current session only.
  ///
  /// This choice should be reset when the app process terminates.
  sessionOnly,
}

// ============================================================================
// Camera Permission Dialog
// ============================================================================

/// Shows a camera permission dialog with three options.
///
/// Returns a [PermissionDialogResult] indicating the user's choice,
/// or `null` if the dialog was dismissed without a selection.
///
/// ## Options
/// - **Deny**: User does not want to grant camera access
/// - **Accept for this session**: Grant access for the current session only
/// - **Accept**: Grant permanent camera access
///
/// ## Usage
/// ```dart
/// final result = await showCameraPermissionDialog(context);
/// if (result == PermissionDialogResult.granted) {
///   // Grant permanent permission
/// } else if (result == PermissionDialogResult.sessionOnly) {
///   // Grant session-only permission
/// } else {
///   // Permission denied or dialog dismissed
/// }
/// ```
///
/// ## Example Integration
/// ```dart
/// Future<void> _handleScanTap(BuildContext context) async {
///   final permissionService = ref.read(cameraPermissionServiceProvider);
///   final state = await permissionService.checkPermission();
///
///   if (state == CameraPermissionState.unknown) {
///     final result = await showCameraPermissionDialog(context);
///     if (result == null) return; // User dismissed
///
///     switch (result) {
///       case PermissionDialogResult.granted:
///         await permissionService.grantPermanentPermission();
///       case PermissionDialogResult.sessionOnly:
///         permissionService.grantSessionPermission();
///       case PermissionDialogResult.denied:
///         await permissionService.denyPermission();
///         return; // Don't proceed with scanning
///     }
///
///     // Request system permission
///     await permissionService.requestSystemPermission();
///   }
///
///   // Proceed with scanning...
/// }
/// ```
Future<PermissionDialogResult?> showCameraPermissionDialog(
  BuildContext context,
) {
  return showDialog<PermissionDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _CameraPermissionDialog(),
  );
}

/// Internal dialog widget for camera permission request.
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AIScan needs access to your camera to scan documents.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Your privacy is important to us. Choose how you would like to grant camera access:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        // Deny button - tertiary action
        TextButton(
          onPressed: () => Navigator.of(context).pop(PermissionDialogResult.denied),
          child: const Text('Deny'),
        ),
        // Row for the two accept options
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Accept for this session - secondary action
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(PermissionDialogResult.sessionOnly),
              child: const Text('This Session'),
            ),
            const SizedBox(width: 8),
            // Accept - primary action
            FilledButton(
              onPressed: () => Navigator.of(context).pop(PermissionDialogResult.granted),
              child: const Text('Accept'),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// Settings Redirect Dialog
// ============================================================================

/// Shows a dialog prompting the user to open settings to enable camera.
///
/// This dialog is shown when the system camera permission has been
/// permanently denied or is restricted. The user must manually enable
/// the permission in device settings.
///
/// Returns `true` if the user chose to open settings, `false` otherwise.
///
/// ## Usage
/// ```dart
/// final shouldOpenSettings = await showCameraSettingsDialog(context);
/// if (shouldOpenSettings) {
///   await permissionService.openSettings();
/// }
/// ```
Future<bool> showCameraSettingsDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const _CameraSettingsDialog(),
  );
  return result ?? false;
}

/// Internal dialog widget for camera settings redirect.
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Camera permission has been denied.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'To scan documents, please enable camera access in your device settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
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
// Permission Denied Snackbar
// ============================================================================

/// Shows a snackbar indicating camera permission was denied.
///
/// Provides an action to re-request permission through settings.
///
/// ## Usage
/// ```dart
/// showCameraPermissionDeniedSnackbar(
///   context,
///   onSettingsPressed: () async {
///     await permissionService.openSettings();
///   },
/// );
/// ```
void showCameraPermissionDeniedSnackbar(
  BuildContext context, {
  VoidCallback? onSettingsPressed,
}) {
  final theme = Theme.of(context);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('Camera permission is required to scan documents'),
      backgroundColor: theme.colorScheme.error,
      action: onSettingsPressed != null
          ? SnackBarAction(
              label: 'Settings',
              textColor: theme.colorScheme.onError,
              onPressed: onSettingsPressed,
            )
          : null,
      duration: const Duration(seconds: 4),
    ),
  );
}
