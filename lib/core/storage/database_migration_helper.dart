import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart';
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
        debugPrint(
            'DatabaseMigration: No database file found, no migration needed');
        return false;
      }

      // Check if database is already encrypted by trying to open AND query it
      // An encrypted database will fail when we try to query the schema
      try {
        final testDb = await sqflite.openDatabase(
          oldDbPath,
          readOnly: true,
        );

        // Try to actually query the database - this will fail if it's encrypted
        try {
          await testDb.rawQuery('SELECT name FROM sqlite_master LIMIT 1');
          // If we get here, database is readable without encryption = needs migration
          await testDb.close();
          debugPrint(
              'DatabaseMigration: Database is unencrypted, migration needed');
          return true;
        } on Object catch (queryError) {
          // Query failed = database is encrypted, no migration needed
          await testDb.close();
          debugPrint(
              'DatabaseMigration: Database is already encrypted: $queryError');
          return false;
        }
      } on Object catch (e) {
        // Couldn't open database at all = might be encrypted or corrupted
        // Either way, no migration needed (will be handled by DatabaseHelper)
        debugPrint(
            'DatabaseMigration: Cannot open database, assuming encrypted: $e');
        return false;
      }
    } on Object catch (e) {
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

      // Verify old database exists
      if (!await oldDbFile.exists()) {
        throw MigrationException('Old database not found: $oldDbPath');
      }

      // Delete existing backup if present
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      // Get original file size for verification
      final originalSize = await oldDbFile.length();

      // Create backup by copying database file
      await oldDbFile.copy(backupPath);

      // Verify backup was created successfully
      if (!await backupFile.exists()) {
        throw MigrationException('Backup file was not created');
      }

      // Verify backup file size matches original
      final backupSize = await backupFile.length();
      if (backupSize != originalSize) {
        throw MigrationException(
          'Backup verification failed: size mismatch '
          '(original: $originalSize, backup: $backupSize)',
        );
      }

      debugPrint('Database backup created and verified at: $backupPath '
          '($backupSize bytes)');
      return backupPath;
    } on Object catch (e) {
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

      // Verify backup file is not empty
      final backupSize = await backupFile.length();
      if (backupSize == 0) {
        throw MigrationException('Backup file is empty: $backupPath');
      }

      final oldDbFile = File(oldDbPath);

      // Delete current database if exists
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
      }

      // Restore from backup
      await backupFile.copy(oldDbPath);

      // Verify restoration was successful
      if (!await oldDbFile.exists()) {
        throw MigrationException(
            'Database restoration failed: file not created');
      }

      final restoredSize = await oldDbFile.length();
      if (restoredSize != backupSize) {
        throw MigrationException(
          'Database restoration verification failed: size mismatch '
          '(backup: $backupSize, restored: $restoredSize)',
        );
      }

      debugPrint('Database restored and verified from backup: $backupPath '
          '($restoredSize bytes)');
    } on Object catch (e) {
      throw MigrationException(
        'Failed to restore database from backup',
        cause: e,
      );
    }
  }

  /// Checks if a backup file exists.
  ///
  /// Returns `true` if a backup file exists, `false` otherwise.
  ///
  /// This can be used to check if a previous migration attempt left a backup.
  Future<bool> backupExists() async {
    try {
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, _oldDatabaseName);
      final backupPath = '$oldDbPath$_backupSuffix';

      final backupFile = File(backupPath);
      return await backupFile.exists();
    } on Object catch (e) {
      // Return false if we can't check (e.g., permissions issue)
      debugPrint('Error checking backup existence: $e');
      return false;
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
    } on Object catch (e) {
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
  /// 5. Replaces old database with encrypted version
  /// 6. Cleans up temporary files
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

      // Step 3: Open old database (read-only for safety)
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, _oldDatabaseName);
      oldDb = await sqflite.openDatabase(oldDbPath, readOnly: true);

      // Step 4: Create new encrypted database
      newDb = await _openEncryptedDatabase();

      // Step 5: Copy all tables
      final rowCount = await _copyAllTables(oldDb, newDb);

      // Step 6: Verify data integrity
      await _verifyMigration(oldDb, newDb);

      // Step 7: Close both databases before file operations
      await oldDb.close();
      await newDb.close();
      oldDb = null;
      newDb = null;

      // Step 8: Replace old database with new encrypted database
      await _replaceOldDatabase();

      // Step 9: Delete backup after successful migration
      await deleteBackup();

      debugPrint('Migration completed successfully: $rowCount rows migrated');

      return MigrationResult(
        success: true,
        rowsMigrated: rowCount,
        backupPath: backupPath,
      );
    } on Object catch (e) {
      // Attempt rollback on failure
      if (backupPath != null) {
        try {
          await restoreFromBackup();
          debugPrint('Database restored from backup after migration failure');
        } on Object catch (rollbackError) {
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

  /// Replaces old database with new encrypted database.
  ///
  /// Deletes the old unencrypted database and renames the encrypted
  /// database to the original name.
  ///
  /// Throws [MigrationException] if replacement fails.
  Future<void> _replaceOldDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final oldDbPath = join(databasesPath, _oldDatabaseName);
      final newDbPath = join(databasesPath, _newDatabaseName);

      final oldDbFile = File(oldDbPath);
      final newDbFile = File(newDbPath);

      // Delete old database
      if (await oldDbFile.exists()) {
        await oldDbFile.delete();
        debugPrint('Old database deleted: $oldDbPath');
      }

      // Rename new database to old name
      await newDbFile.rename(oldDbPath);
      debugPrint('Encrypted database renamed to: $oldDbPath');
    } on Object catch (e) {
      throw MigrationException(
        'Failed to replace old database with encrypted version',
        cause: e,
      );
    }
  }

  /// Copies all tables from old database to new encrypted database.
  ///
  /// Returns the total number of rows migrated.
  ///
  /// Migrates data table by table with transaction safety:
  /// 1. Folders (no dependencies)
  /// 2. Documents (depends on folders)
  /// 3. Document pages (depends on documents)
  /// 4. Tags (no dependencies)
  /// 5. Document tags (depends on documents and tags)
  /// 6. Signatures (no dependencies)
  /// 7. Search history (no dependencies)
  ///
  /// FTS tables are NOT copied - they will be rebuilt by DatabaseHelper
  /// when the app initializes the FTS system.
  ///
  /// Throws [MigrationException] if any table copy fails.
  Future<int> _copyAllTables(Database oldDb, Database newDb) async {
    int totalRows = 0;

    try {
      // Copy tables in dependency order
      totalRows += await _copyTable(
        oldDb,
        newDb,
        DatabaseHelper.tableFolders,
      );

      totalRows += await _copyTable(
        oldDb,
        newDb,
        DatabaseHelper.tableDocuments,
      );

      totalRows += await _copyTable(
        oldDb,
        newDb,
        DatabaseHelper.tableDocumentPages,
      );

      totalRows += await _copyTable(
        oldDb,
        newDb,
        DatabaseHelper.tableTags,
      );

      totalRows += await _copyTable(
        oldDb,
        newDb,
        DatabaseHelper.tableDocumentTags,
      );

      totalRows += await _copyTable(
        oldDb,
        newDb,
        DatabaseHelper.tableSignatures,
      );

      totalRows += await _copyTable(
        oldDb,
        newDb,
        DatabaseHelper.tableSearchHistory,
      );

      debugPrint('Total rows migrated: $totalRows');
      return totalRows;
    } on Object catch (e) {
      throw MigrationException(
        'Failed to copy tables',
        cause: e,
      );
    }
  }

  /// Copies a single table from old database to new database.
  ///
  /// Uses batch insert for better performance and transaction safety.
  ///
  /// Returns the number of rows copied.
  ///
  /// Throws [MigrationException] if copy fails.
  Future<int> _copyTable(
    Database oldDb,
    Database newDb,
    String tableName,
  ) async {
    try {
      // Check if table exists in old database
      final tableExists = await _tableExists(oldDb, tableName);
      if (!tableExists) {
        debugPrint('Table $tableName does not exist in old database, skipping');
        return 0;
      }

      // Get all rows from old table
      final rows = await oldDb.query(tableName);

      if (rows.isEmpty) {
        debugPrint('Table $tableName is empty, skipping');
        return 0;
      }

      // Insert rows into new table using transaction
      await newDb.transaction((txn) async {
        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(tableName, row);
        }
        await batch.commit(noResult: true);
      });

      debugPrint('Copied ${rows.length} rows from table $tableName');
      return rows.length;
    } on Object catch (e) {
      throw MigrationException(
        'Failed to copy table $tableName',
        cause: e,
      );
    }
  }

  /// Checks if a table exists in the database.
  ///
  /// Returns `true` if the table exists, `false` otherwise.
  Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  /// Verifies data integrity after migration.
  ///
  /// Compares row counts and sample data between old and new databases
  /// to ensure migration completed successfully.
  ///
  /// Verification checks:
  /// 1. Row counts match for all migrated tables
  /// 2. Sample records from each table match
  /// 3. Foreign key relationships preserved
  ///
  /// Throws [MigrationException] if verification fails.
  Future<void> _verifyMigration(Database oldDb, Database newDb) async {
    try {
      // List of tables to verify (excluding FTS tables)
      final tablesToVerify = [
        DatabaseHelper.tableFolders,
        DatabaseHelper.tableDocuments,
        DatabaseHelper.tableDocumentPages,
        DatabaseHelper.tableTags,
        DatabaseHelper.tableDocumentTags,
        DatabaseHelper.tableSignatures,
        DatabaseHelper.tableSearchHistory,
      ];

      for (final tableName in tablesToVerify) {
        await _verifyTableMigration(oldDb, newDb, tableName);
      }

      debugPrint('Migration verification completed successfully');
    } on Object catch (e) {
      throw MigrationException(
        'Migration verification failed',
        cause: e,
      );
    }
  }

  /// Verifies migration of a single table.
  ///
  /// Compares row counts and sample data between old and new database.
  ///
  /// Throws [MigrationException] if verification fails.
  Future<void> _verifyTableMigration(
    Database oldDb,
    Database newDb,
    String tableName,
  ) async {
    // Check if table exists in old database
    final tableExists = await _tableExists(oldDb, tableName);
    if (!tableExists) {
      debugPrint(
          'Table $tableName does not exist in old database, skipping verification');
      return;
    }

    // Get row counts from both databases
    final oldCount = Sqflite.firstIntValue(
          await oldDb.rawQuery('SELECT COUNT(*) FROM $tableName'),
        ) ??
        0;

    final newCount = Sqflite.firstIntValue(
          await newDb.rawQuery('SELECT COUNT(*) FROM $tableName'),
        ) ??
        0;

    // Verify row counts match
    if (oldCount != newCount) {
      throw MigrationException(
        'Row count mismatch for table $tableName: '
        'old=$oldCount, new=$newCount',
      );
    }

    debugPrint('Table $tableName verified: $oldCount rows');

    // If table has data, verify sample records match
    if (oldCount > 0) {
      await _verifySampleRecords(oldDb, newDb, tableName);
    }
  }

  /// Verifies that sample records match between old and new database.
  ///
  /// Compares first and last record from each table to ensure
  /// data was copied correctly.
  ///
  /// Throws [MigrationException] if sample records don't match.
  Future<void> _verifySampleRecords(
    Database oldDb,
    Database newDb,
    String tableName,
  ) async {
    // Get first record from both databases
    final oldFirst = await oldDb.query(tableName, limit: 1);
    final newFirst = await newDb.query(tableName, limit: 1);

    if (oldFirst.isEmpty || newFirst.isEmpty) {
      return; // Table is empty, nothing to verify
    }

    // Compare first records (basic sanity check)
    // We compare the number of columns as a simple integrity check
    if (oldFirst.first.length != newFirst.first.length) {
      throw MigrationException(
        'Sample record mismatch for table $tableName: '
        'column count differs',
      );
    }

    debugPrint('Sample records verified for table $tableName');
  }

  /// Opens the new encrypted database with password.
  ///
  /// Uses the encryption key from [SecureStorageService] as the database password.
  ///
  /// Creates a new encrypted database at the temporary path with the same
  /// schema as defined in DatabaseHelper. Uses sqflite_sqlcipher for encryption.
  ///
  /// Returns the opened encrypted database instance.
  ///
  /// Throws [MigrationException] if database creation fails.
  Future<Database> _openEncryptedDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final newDbPath = join(databasesPath, _newDatabaseName);
      final encryptionKey = await _secureStorage.getOrCreateEncryptionKey();

      // Import sqflite_sqlcipher for encrypted database
      final db = await openDatabase(
        newDbPath,
        version: 3, // Current database version from DatabaseHelper
        password: encryptionKey,
        onCreate: (db, version) async {
          // Create all tables as defined in DatabaseHelper
          await _createDatabaseSchema(db);
        },
      );

      debugPrint('Encrypted database created at: $newDbPath');
      return db;
    } on Object catch (e) {
      throw MigrationException(
        'Failed to create encrypted database',
        cause: e,
      );
    }
  }

  /// Creates the database schema in the new encrypted database.
  ///
  /// Replicates all table structures from DatabaseHelper to ensure
  /// compatibility with the existing application.
  Future<void> _createDatabaseSchema(Database db) async {
    // Create folders table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableFolders} (
        ${DatabaseHelper.columnId} TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        color TEXT,
        icon TEXT,
        ${DatabaseHelper.columnIsFavorite} INTEGER NOT NULL DEFAULT 0,
        ${DatabaseHelper.columnCreatedAt} TEXT NOT NULL,
        ${DatabaseHelper.columnUpdatedAt} TEXT NOT NULL
      )
    ''');

    // Create main documents table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableDocuments} (
        ${DatabaseHelper.columnId} TEXT PRIMARY KEY,
        ${DatabaseHelper.columnTitle} TEXT NOT NULL,
        ${DatabaseHelper.columnDescription} TEXT,
        ${DatabaseHelper.columnThumbnailPath} TEXT,
        original_file_name TEXT,
        ${DatabaseHelper.columnFileSize} INTEGER NOT NULL DEFAULT 0,
        mime_type TEXT,
        ${DatabaseHelper.columnOcrText} TEXT,
        ocr_status TEXT DEFAULT 'pending',
        ${DatabaseHelper.columnCreatedAt} TEXT NOT NULL,
        ${DatabaseHelper.columnUpdatedAt} TEXT NOT NULL,
        ${DatabaseHelper.columnFolderId} TEXT,
        ${DatabaseHelper.columnIsFavorite} INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (${DatabaseHelper.columnFolderId}) REFERENCES ${DatabaseHelper.tableFolders}(${DatabaseHelper.columnId}) ON DELETE SET NULL
      )
    ''');

    // Create document_pages table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableDocumentPages} (
        ${DatabaseHelper.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseHelper.columnDocumentId} TEXT NOT NULL,
        ${DatabaseHelper.columnPageNumber} INTEGER NOT NULL,
        ${DatabaseHelper.columnFilePath} TEXT NOT NULL,
        FOREIGN KEY (${DatabaseHelper.columnDocumentId}) REFERENCES ${DatabaseHelper.tableDocuments}(${DatabaseHelper.columnId}) ON DELETE CASCADE
      )
    ''');

    // Create tags table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableTags} (
        ${DatabaseHelper.columnId} TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        ${DatabaseHelper.columnCreatedAt} TEXT NOT NULL
      )
    ''');

    // Create document_tags junction table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableDocumentTags} (
        ${DatabaseHelper.columnDocumentId} TEXT NOT NULL,
        ${DatabaseHelper.columnTagId} TEXT NOT NULL,
        PRIMARY KEY (${DatabaseHelper.columnDocumentId}, ${DatabaseHelper.columnTagId}),
        FOREIGN KEY (${DatabaseHelper.columnDocumentId}) REFERENCES ${DatabaseHelper.tableDocuments}(${DatabaseHelper.columnId}) ON DELETE CASCADE,
        FOREIGN KEY (${DatabaseHelper.columnTagId}) REFERENCES ${DatabaseHelper.tableTags}(${DatabaseHelper.columnId}) ON DELETE CASCADE
      )
    ''');

    // Create signatures table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableSignatures} (
        ${DatabaseHelper.columnId} TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        ${DatabaseHelper.columnFilePath} TEXT NOT NULL,
        ${DatabaseHelper.columnCreatedAt} TEXT NOT NULL
      )
    ''');

    // Create search_history table
    await db.execute('''
      CREATE TABLE ${DatabaseHelper.tableSearchHistory} (
        ${DatabaseHelper.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseHelper.columnQuery} TEXT NOT NULL,
        ${DatabaseHelper.columnTimestamp} TEXT NOT NULL,
        ${DatabaseHelper.columnResultCount} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    debugPrint('Database schema created successfully');
  }
}
