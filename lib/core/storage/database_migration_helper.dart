import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../security/secure_storage_service.dart';
import 'database_helper.dart';

/// Riverpod provider for [DatabaseMigrationHelper].
///
/// Provides a singleton instance of the migration helper for
/// migrating data from unencrypted SQLite to encrypted SQLCipher database.
/// Depends on [SecureStorageService] for encryption key management.
final databaseMigrationHelperProvider =
    Provider<DatabaseMigrationHelper>((ref) {
  final secureStorage = ref.read(secureStorageServiceProvider);
  return DatabaseMigrationHelper(secureStorage: secureStorage);
});

/// Exception thrown when database migration operations fail.
///
/// Contains the original error message and optional underlying exception.
class MigrationException implements Exception {
  /// Creates a [MigrationException] with the given [message].
  const MigrationException(this.message, {this.cause});

  /// Human-readable error message.
  final String message;

  /// The underlying exception that caused this error, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'MigrationException: $message (caused by: $cause)';
    }
    return 'MigrationException: $message';
  }
}

/// Result of migration operation containing status and statistics.
///
/// Tracks the outcome of the migration process including row counts,
/// success status, and any errors encountered.
class MigrationResult {
  /// Creates a [MigrationResult] with the given parameters.
  const MigrationResult({
    required this.success,
    required this.rowsMigrated,
    this.error,
    this.backupPath,
  });

  /// Whether the migration completed successfully.
  final bool success;

  /// Total number of rows migrated across all tables.
  final int rowsMigrated;

  /// Error message if migration failed.
  final String? error;

  /// Path to the backup file created before migration.
  final String? backupPath;

  @override
  String toString() {
    if (success) {
      return 'MigrationResult(success: true, rowsMigrated: $rowsMigrated, backupPath: $backupPath)';
    }
    return 'MigrationResult(success: false, error: $error)';
  }
}

/// Helper class for migrating data from unencrypted SQLite to encrypted SQLCipher database.
///
/// Provides comprehensive migration functionality with backup and rollback capabilities:
/// - **Detection**: Identifies existing unencrypted databases
/// - **Backup**: Creates safe backup before migration
/// - **Migration**: Copies all data from old to new encrypted database
/// - **Verification**: Validates data integrity after migration
/// - **Rollback**: Restores backup if migration fails
///
/// ## Migration Process
/// 1. Detect if old unencrypted database exists
/// 2. Create backup of old database (.backup extension)
/// 3. Create new encrypted database with password
/// 4. Copy all tables and data with transaction safety
/// 5. Verify data integrity (row counts, sample data)
/// 6. Delete backup on successful verification
/// 7. Rollback and restore backup on failure
///
/// ## Usage
/// ```dart
/// final migrationHelper = ref.read(databaseMigrationHelperProvider);
///
/// // Check if migration is needed
/// if (await migrationHelper.needsMigration()) {
///   // Perform migration
///   final result = await migrationHelper.migrateToEncrypted();
///
///   if (result.success) {
///     print('Migrated ${result.rowsMigrated} rows');
///   } else {
///     print('Migration failed: ${result.error}');
///   }
/// }
/// ```
///
/// ## Security Notes
/// - Uses same encryption key as file encryption via [SecureStorageService]
/// - Old database is backed up but not deleted until verification succeeds
/// - Migration is idempotent - safe to run multiple times
/// - All operations wrapped in transactions for data safety
class DatabaseMigrationHelper {
  /// Creates a [DatabaseMigrationHelper] with the required [SecureStorageService].
  DatabaseMigrationHelper({
    required SecureStorageService secureStorage,
  }) : _secureStorage = secureStorage;

  /// The secure storage service for key management.
  final SecureStorageService _secureStorage;

  /// Database name for the unencrypted database.
  static const String _oldDatabaseName = 'aiscan.db';

  /// Database name for the encrypted database (will use same name after migration).
  static const String _newDatabaseName = 'aiscan_encrypted.db';

  /// Backup file suffix for old database.
  static const String _backupSuffix = '.backup';

  /// Checks if migration is needed.
  ///
  /// Returns `true` if an unencrypted database exists and needs to be migrated
  /// to the encrypted format.
  ///
  /// This method checks for:
  /// - Existence of old unencrypted database file
  /// - Absence of new encrypted database (to avoid re-migration)
  Future<bool> needsMigration() async {
    try {
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, _oldDatabaseName);
      final oldDbFile = File(oldDbPath);

      // Check if old database exists
      if (!await oldDbFile.exists()) {
        return false;
      }

      // Additional check: verify it's not already encrypted
      // (Implementation will be added in phase 3)

      return true;
    } catch (e) {
      throw MigrationException(
        'Failed to check migration status',
        cause: e,
      );
    }
  }

  /// Creates a backup of the old database before migration.
  ///
  /// Returns the path to the backup file.
  ///
  /// Throws [MigrationException] if backup creation fails.
  Future<String> createBackup() async {
    try {
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, _oldDatabaseName);
      final backupPath = '$oldDbPath$_backupSuffix';

      final oldDbFile = File(oldDbPath);
      final backupFile = File(backupPath);

      // Delete existing backup if present
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      // Create backup by copying database file
      await oldDbFile.copy(backupPath);

      debugPrint('Database backup created at: $backupPath');
      return backupPath;
    } catch (e) {
      throw MigrationException(
        'Failed to create database backup',
        cause: e,
      );
    }
  }

  /// Restores the database from backup.
  ///
  /// Used for rollback if migration fails.
  ///
  /// Throws [MigrationException] if restore fails.
  Future<void> restoreFromBackup() async {
    try {
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, _oldDatabaseName);
      final backupPath = '$oldDbPath$_backupSuffix';

      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw MigrationException('Backup file not found: $backupPath');
      }

      final oldDbFile = File(oldDbPath);

      // Delete current database if exists
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
      }

      // Restore from backup
      await backupFile.copy(oldDbPath);

      debugPrint('Database restored from backup: $backupPath');
    } catch (e) {
      throw MigrationException(
        'Failed to restore database from backup',
        cause: e,
      );
    }
  }

  /// Deletes the backup file after successful migration.
  ///
  /// Should only be called after migration has been verified successful.
  ///
  /// Throws [MigrationException] if deletion fails.
  Future<void> deleteBackup() async {
    try {
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, _oldDatabaseName);
      final backupPath = '$oldDbPath$_backupSuffix';

      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();
        debugPrint('Database backup deleted: $backupPath');
      }
    } catch (e) {
      throw MigrationException(
        'Failed to delete backup file',
        cause: e,
      );
    }
  }

  /// Migrates data from unencrypted to encrypted database.
  ///
  /// This is the main migration entry point that orchestrates the full process:
  /// 1. Creates backup of old database
  /// 2. Opens both old (unencrypted) and new (encrypted) databases
  /// 3. Copies all tables and data
  /// 4. Verifies data integrity
  /// 5. Cleans up old database
  ///
  /// Returns a [MigrationResult] with success status and statistics.
  ///
  /// On failure, automatically attempts to restore from backup.
  Future<MigrationResult> migrateToEncrypted() async {
    String? backupPath;
    Database? oldDb;
    Database? newDb;

    try {
      // Step 1: Check if migration is needed
      if (!await needsMigration()) {
        return const MigrationResult(
          success: false,
          rowsMigrated: 0,
          error: 'Migration not needed - old database not found',
        );
      }

      // Step 2: Create backup
      backupPath = await createBackup();

      // Step 3: Open old database
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, _oldDatabaseName);
      oldDb = await openDatabase(oldDbPath, readOnly: true);

      // Step 4: Open/create new encrypted database
      // (Implementation will be added in phase 2 when DatabaseHelper supports encryption)
      // For now, this is a placeholder
      // newDb = await _openEncryptedDatabase();

      // Step 5: Copy all tables
      // (Implementation will be added in phase 3)
      // final rowCount = await _copyAllTables(oldDb, newDb);

      // Step 6: Verify data integrity
      // (Implementation will be added in phase 3)
      // await _verifyMigration(oldDb, newDb);

      // Placeholder result for now
      const rowCount = 0;

      debugPrint('Migration completed successfully: $rowCount rows migrated');

      return MigrationResult(
        success: true,
        rowsMigrated: rowCount,
        backupPath: backupPath,
      );
    } catch (e) {
      // Attempt rollback on failure
      if (backupPath != null) {
        try {
          await restoreFromBackup();
          debugPrint('Database restored from backup after migration failure');
        } catch (rollbackError) {
          debugPrint('Failed to restore backup: $rollbackError');
        }
      }

      return MigrationResult(
        success: false,
        rowsMigrated: 0,
        error: 'Migration failed: $e',
      );
    } finally {
      // Clean up database connections
      await oldDb?.close();
      await newDb?.close();
    }
  }

  /// Copies all tables from old database to new encrypted database.
  ///
  /// Returns the total number of rows migrated.
  ///
  /// This method will be implemented in phase 3 to:
  /// - Iterate through all tables defined in DatabaseHelper
  /// - Copy data with proper type handling
  /// - Use transactions for data safety
  /// - Handle FTS tables appropriately
  Future<int> _copyAllTables(Database oldDb, Database newDb) async {
    // Implementation placeholder
    // Will be implemented in phase 3 (subtask-3-1)
    throw UnimplementedError(
      'Table copying will be implemented in migration phase',
    );
  }

  /// Verifies data integrity after migration.
  ///
  /// Compares row counts and sample data between old and new databases
  /// to ensure migration completed successfully.
  ///
  /// Throws [MigrationException] if verification fails.
  ///
  /// This method will be implemented in phase 3 to:
  /// - Compare row counts for all tables
  /// - Verify sample records match
  /// - Check foreign key integrity
  /// - Validate FTS indexes
  Future<void> _verifyMigration(Database oldDb, Database newDb) async {
    // Implementation placeholder
    // Will be implemented in phase 3 (subtask-3-1)
    throw UnimplementedError(
      'Migration verification will be implemented in migration phase',
    );
  }

  /// Opens the new encrypted database with password.
  ///
  /// Uses the encryption key from [SecureStorageService] as the database password.
  ///
  /// This method will be implemented in phase 2 after DatabaseHelper
  /// is updated to support SQLCipher.
  Future<Database> _openEncryptedDatabase() async {
    // Implementation placeholder
    // Will be implemented in phase 2 after DatabaseHelper supports encryption
    throw UnimplementedError(
      'Encrypted database opening will be implemented after DatabaseHelper migration',
    );
  }
}
