/// Permission handling for scanner screen.
///
/// This file provides camera and storage permission handling
/// for the scanner screen, including permission requests and
/// automatic scan initiation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/camera_permission_service.dart';
import '../../../../core/permissions/permission_dialog.dart';
import '../../../../core/permissions/storage_permission_service.dart';
import '../state/scanner_screen_notifier.dart';

/// Handles permission logic for scanner screen.
class ScannerPermissionHandler {
  final WidgetRef ref;
  final BuildContext context;

  const ScannerPermissionHandler(this.ref, this.context);

  /// Automatically starts scan after checking permissions.
  Future<void> autoStartScan() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission && context.mounted) {
      // Permission denied, go back
      Navigator.of(context).pop();
      return;
    }
    if (hasPermission && context.mounted) {
      // Check storage permission to determine if gallery import should be enabled
      final storageService = ref.read(storagePermissionServiceProvider);
      final storageState = await storageService.checkPermission();
      final hasStoragePermission =
          storageState == StoragePermissionState.granted ||
              storageState == StoragePermissionState.sessionOnly;

      // Only enable gallery import if storage permission is granted
      ref.read(scannerScreenProvider.notifier).multiPageScan(
            allowGalleryImport: hasStoragePermission,
          );
    }
  }

  /// Checks camera permission and shows dialog if needed.
  ///
  /// Returns `true` if permission is granted (permanent or session),
  /// `false` if denied or cancelled.
  Future<bool> checkAndRequestPermission() async {
    final permissionService = ref.read(cameraPermissionServiceProvider);
    final state = await permissionService.checkPermission();

    // If already granted, proceed
    if (state == CameraPermissionState.granted ||
        state == CameraPermissionState.sessionOnly) {
      return true;
    }

    // Check if this is a first-time request or if permission is blocked
    if (await permissionService.isFirstTimeRequest()) {
      // Show native Android permission dialog
      final result = await permissionService.requestSystemPermission();

      if (result == CameraPermissionState.granted ||
          result == CameraPermissionState.sessionOnly) {
        return true;
      }

      // Permission denied, show snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Camera permission is required to scan documents'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => permissionService.openSettings(),
            ),
          ),
        );
      }
      return false;
    }

    // Permission is blocked, show settings dialog
    if (await permissionService.isPermissionBlocked()) {
      if (!context.mounted) return false;

      final shouldOpenSettings = await showCameraSettingsDialog(context);
      if (shouldOpenSettings == true) {
        await permissionService.openSettings();
      }
      return false;
    }

    return false;
  }
}
