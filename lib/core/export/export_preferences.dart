import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../exceptions/base_exception.dart';

/// Riverpod provider for [ExportPreferences].
///
/// Provides a singleton instance of the export preferences service for
/// dependency injection throughout the application.
///
/// This provider creates the preferences instance asynchronously since
/// SharedPreferences requires initialization.
final exportPreferencesProvider = Provider<ExportPreferences>((ref) {
  return ExportPreferences();
});

/// Exception thrown when export preferences operations fail.
///
/// Contains the original error message and optional underlying exception.
class ExportPreferencesException extends BaseException {
  /// Creates an [ExportPreferencesException] with the given [message].
  const ExportPreferencesException(super.message, {super.cause});
}

/// Service for managing export preferences using SharedPreferences.
///
/// This service handles storage and retrieval of export-related user preferences,
/// primarily the last used export folder path for SAF (Storage Access Framework)
/// operations.
///
/// ## Usage
/// ```dart
/// final exportPrefs = ref.read(exportPreferencesProvider);
///
/// // Get the last export folder
/// final lastFolder = await exportPrefs.getLastExportFolder();
///
/// // Save the last export folder
/// await exportPrefs.setLastExportFolder('/storage/emulated/0/Documents');
///
/// // Clear the last export folder
/// await exportPrefs.clearLastExportFolder();
/// ```
///
/// ## Storage
/// All preferences are stored using SharedPreferences with the following keys:
/// - `aiscan_export_last_folder`: Last used export folder path
///
/// ## Notes
/// - The stored folder path is a String URI from the SAF picker
/// - Returns `null` if no folder has been previously selected
/// - The folder path is persisted across app restarts
class ExportPreferences {
  /// Creates an [ExportPreferences] instance.
  ///
  /// Optionally accepts a [SharedPreferences] instance for testing.
  ExportPreferences({
    SharedPreferences? sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  /// The SharedPreferences instance (lazy loaded if not provided).
  SharedPreferences? _sharedPreferences;

  /// Key used to store the last export folder path in SharedPreferences.
  static const String _lastExportFolderKey = 'aiscan_export_last_folder';

  /// Key used to store the last export folder display name.
  static const String _lastExportFolderNameKey =
      'aiscan_export_last_folder_name';

  /// Ensures SharedPreferences is initialized.
  ///
  /// Returns the [SharedPreferences] instance.
  Future<SharedPreferences> _getPreferences() async {
    _sharedPreferences ??= await SharedPreferences.getInstance();
    return _sharedPreferences!;
  }

  /// Retrieves the last used export folder path.
  ///
  /// Returns the stored folder path as a String, or `null` if no folder
  /// has been previously selected.
  ///
  /// Throws [ExportPreferencesException] if the read operation fails.
  ///
  /// ## Example
  /// ```dart
  /// final lastFolder = await exportPrefs.getLastExportFolder();
  /// if (lastFolder != null) {
  ///   // Use the last folder as default
  /// } else {
  ///   // First time export, show folder picker
  /// }
  /// ```
  Future<String?> getLastExportFolder() async {
    try {
      final prefs = await _getPreferences();
      return prefs.getString(_lastExportFolderKey);
    } on Exception catch (e) {
      throw ExportPreferencesException(
        'Failed to retrieve last export folder',
        cause: e,
      );
    }
  }

  /// Stores the last used export folder path.
  ///
  /// The [folderPath] should be the String URI returned by the SAF picker.
  /// Pass an optional [displayName] for user-friendly display.
  ///
  /// Throws [ExportPreferencesException] if the write operation fails.
  ///
  /// ## Example
  /// ```dart
  /// // After user selects a folder via SAF picker
  /// await exportPrefs.setLastExportFolder(
  ///   selectedFolderUri,
  ///   displayName: 'Documents',
  /// );
  /// ```
  Future<void> setLastExportFolder(
    String folderPath, {
    String? displayName,
  }) async {
    try {
      final prefs = await _getPreferences();
      await prefs.setString(_lastExportFolderKey, folderPath);
      if (displayName != null) {
        await prefs.setString(_lastExportFolderNameKey, displayName);
      }
    } on Exception catch (e) {
      throw ExportPreferencesException(
        'Failed to store last export folder',
        cause: e,
      );
    }
  }

  /// Retrieves the display name of the last used export folder.
  ///
  /// Returns the stored folder display name, or `null` if not set.
  ///
  /// Throws [ExportPreferencesException] if the read operation fails.
  Future<String?> getLastExportFolderName() async {
    try {
      final prefs = await _getPreferences();
      return prefs.getString(_lastExportFolderNameKey);
    } on Exception catch (e) {
      throw ExportPreferencesException(
        'Failed to retrieve last export folder name',
        cause: e,
      );
    }
  }

  /// Clears the stored last export folder preference.
  ///
  /// Use this when the user wants to reset their export location preference
  /// or when the previously selected folder is no longer accessible.
  ///
  /// Throws [ExportPreferencesException] if the delete operation fails.
  ///
  /// ## Example
  /// ```dart
  /// // Reset export folder preference
  /// await exportPrefs.clearLastExportFolder();
  /// ```
  Future<void> clearLastExportFolder() async {
    try {
      final prefs = await _getPreferences();
      await prefs.remove(_lastExportFolderKey);
      await prefs.remove(_lastExportFolderNameKey);
    } on Exception catch (e) {
      throw ExportPreferencesException(
        'Failed to clear last export folder',
        cause: e,
      );
    }
  }

  /// Checks if a last export folder has been stored.
  ///
  /// Returns `true` if a folder path is stored, `false` otherwise.
  ///
  /// Throws [ExportPreferencesException] if the check fails.
  Future<bool> hasLastExportFolder() async {
    try {
      final prefs = await _getPreferences();
      return prefs.containsKey(_lastExportFolderKey);
    } on Exception catch (e) {
      throw ExportPreferencesException(
        'Failed to check last export folder',
        cause: e,
      );
    }
  }
}
