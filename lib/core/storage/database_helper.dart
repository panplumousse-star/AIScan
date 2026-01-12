import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Database helper class for managing SQLite database operations.
///
/// Implements FTS5/FTS4 fallback strategy for full-text search capabilities.
/// Supports three modes:
/// - FTS5 (version 5): Best performance with rank ordering
/// - FTS4 (version 4): Universal compatibility fallback
/// - Disabled (version 0): LIKE-based search when FTS unavailable
class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // Database configuration
  static const String _databaseName = 'aiscan.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String tableDocuments = 'documents';
  static const String tableDocumentsFts = 'documents_fts';

  // Column names for documents table
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDescription = 'description';
  static const String columnOcrText = 'ocr_text';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  /// Active FTS version: 5 (FTS5), 4 (FTS4), or 0 (disabled)
  ///
  /// This variable tracks the detected FTS capability at runtime:
  /// - 5: FTS5 module is available (best performance with rank ordering)
  /// - 4: FTS4 module is available (fallback with basic ordering)
  /// - 0: No FTS module available (uses LIKE-based search)
  static int _ftsVersion = 0;

  /// Gets the currently active FTS version.
  ///
  /// Returns:
  /// - 5 if FTS5 is available and initialized
  /// - 4 if FTS4 is being used as fallback
  /// - 0 if FTS is completely disabled
  static int get ftsVersion => _ftsVersion;

  /// Gets the database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the database.
  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates database tables and FTS indexes.
  Future<void> _onCreate(Database db, int version) async {
    // Create main documents table
    await db.execute('''
      CREATE TABLE $tableDocuments (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDescription TEXT,
        $columnOcrText TEXT,
        $columnCreatedAt TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL
      )
    ''');

    // TODO: Initialize FTS tables and triggers via _initializeFts()
    // Will be implemented in subsequent subtasks
  }

  /// Handles database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Resets the FTS version (primarily for testing purposes).
  @visibleForTesting
  static void resetFtsVersion() {
    _ftsVersion = 0;
  }

  /// Sets the FTS version (internal use only).
  ///
  /// This should only be called during FTS initialization.
  @protected
  static void setFtsVersion(int version) {
    assert(version >= 0 && version <= 5, 'FTS version must be 0, 4, or 5');
    _ftsVersion = version;
  }

  /// Creates FTS5 virtual table for full-text search.
  ///
  /// FTS5 provides the best search performance with:
  /// - Built-in `rank` column for relevance ordering
  /// - `content=` option for external content tables
  /// - `content_rowid=` option to specify the rowid column
  ///
  /// Throws [DatabaseException] with 'no such module: fts5' if FTS5
  /// is not available on the device.
  Future<void> _createFts5Tables(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE $tableDocumentsFts USING fts5(
        $columnTitle,
        $columnDescription,
        $columnOcrText,
        content=$tableDocuments,
        content_rowid=rowid
      )
    ''');
  }

  /// Creates FTS5 triggers to keep the FTS index synchronized with the main table.
  ///
  /// FTS5 external content tables require triggers to maintain synchronization:
  /// - `documents_ai`: AFTER INSERT - adds new documents to FTS index
  /// - `documents_ad`: AFTER DELETE - removes deleted documents from FTS index
  /// - `documents_au`: AFTER UPDATE - updates modified documents in FTS index
  ///
  /// Note: FTS5 uses a special 'delete' command syntax for removing entries,
  /// which differs from FTS4's standard DELETE statement.
  Future<void> _createFts5Triggers(Database db) async {
    // AFTER INSERT trigger - add new document to FTS index
    await db.execute('''
      CREATE TRIGGER documents_ai AFTER INSERT ON $tableDocuments BEGIN
        INSERT INTO $tableDocumentsFts(rowid, $columnTitle, $columnDescription, $columnOcrText)
        VALUES (NEW.rowid, NEW.$columnTitle, NEW.$columnDescription, NEW.$columnOcrText);
      END
    ''');

    // AFTER DELETE trigger - remove document from FTS index
    // FTS5 uses special INSERT with 'delete' command (not standard DELETE)
    await db.execute('''
      CREATE TRIGGER documents_ad AFTER DELETE ON $tableDocuments BEGIN
        INSERT INTO $tableDocumentsFts($tableDocumentsFts, rowid, $columnTitle, $columnDescription, $columnOcrText)
        VALUES ('delete', OLD.rowid, OLD.$columnTitle, OLD.$columnDescription, OLD.$columnOcrText);
      END
    ''');

    // AFTER UPDATE trigger - update document in FTS index
    // FTS5 requires delete of old entry followed by insert of new entry
    await db.execute('''
      CREATE TRIGGER documents_au AFTER UPDATE ON $tableDocuments BEGIN
        INSERT INTO $tableDocumentsFts($tableDocumentsFts, rowid, $columnTitle, $columnDescription, $columnOcrText)
        VALUES ('delete', OLD.rowid, OLD.$columnTitle, OLD.$columnDescription, OLD.$columnOcrText);
        INSERT INTO $tableDocumentsFts(rowid, $columnTitle, $columnDescription, $columnOcrText)
        VALUES (NEW.rowid, NEW.$columnTitle, NEW.$columnDescription, NEW.$columnOcrText);
      END
    ''');
  }

  /// Creates FTS4 virtual table for full-text search (fallback).
  ///
  /// FTS4 provides universal compatibility with older Android devices:
  /// - Uses `content=` option for external content tables (quoted table name)
  /// - Uses `docid` as the implicit rowid reference
  /// - No built-in `rank` column (requires manual matchinfo() for relevance)
  ///
  /// Throws [DatabaseException] with 'no such module: fts4' if FTS4
  /// is not available on the device.
  Future<void> _createFts4Tables(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE $tableDocumentsFts USING fts4(
        $columnTitle,
        $columnDescription,
        $columnOcrText,
        content="$tableDocuments"
      )
    ''');
  }

  /// Creates FTS4 triggers to keep the FTS index synchronized with the main table.
  ///
  /// FTS4 external content tables require triggers to maintain synchronization:
  /// - `documents_ai`: AFTER INSERT - adds new documents to FTS index
  /// - `documents_ad`: AFTER DELETE - removes deleted documents from FTS index
  /// - `documents_au`: AFTER UPDATE - updates modified documents in FTS index
  ///
  /// Note: FTS4 uses standard DELETE statement syntax for removing entries,
  /// which differs from FTS5's special 'delete' command syntax.
  Future<void> _createFts4Triggers(Database db) async {
    // AFTER INSERT trigger - add new document to FTS index
    // FTS4 uses docid instead of rowid for the primary key reference
    await db.execute('''
      CREATE TRIGGER documents_ai AFTER INSERT ON $tableDocuments BEGIN
        INSERT INTO $tableDocumentsFts(docid, $columnTitle, $columnDescription, $columnOcrText)
        VALUES (NEW.rowid, NEW.$columnTitle, NEW.$columnDescription, NEW.$columnOcrText);
      END
    ''');

    // AFTER DELETE trigger - remove document from FTS index
    // FTS4 uses standard DELETE statement (not FTS5's special INSERT syntax)
    await db.execute('''
      CREATE TRIGGER documents_ad AFTER DELETE ON $tableDocuments BEGIN
        DELETE FROM $tableDocumentsFts WHERE docid = OLD.rowid;
      END
    ''');

    // AFTER UPDATE trigger - update document in FTS index
    // FTS4 requires delete of old entry followed by insert of new entry
    await db.execute('''
      CREATE TRIGGER documents_au AFTER UPDATE ON $tableDocuments BEGIN
        DELETE FROM $tableDocumentsFts WHERE docid = OLD.rowid;
        INSERT INTO $tableDocumentsFts(docid, $columnTitle, $columnDescription, $columnOcrText)
        VALUES (NEW.rowid, NEW.$columnTitle, NEW.$columnDescription, NEW.$columnOcrText);
      END
    ''');
  }

  /// Initializes FTS (Full-Text Search) tables with automatic fallback.
  ///
  /// Implements a three-tier fallback strategy:
  /// 1. FTS5 (best performance with rank ordering)
  /// 2. FTS4 (universal compatibility fallback)
  /// 3. Disabled (graceful degradation with LIKE-based search)
  ///
  /// This method detects FTS module availability at runtime by attempting
  /// to create FTS virtual tables and catching "no such module" errors.
  /// The detected version is stored in [_ftsVersion] for use by search methods.
  ///
  /// Should be called during database creation in [_onCreate].
  ///
  /// Example:
  /// ```dart
  /// Future<void> _onCreate(Database db, int version) async {
  ///   await db.execute('CREATE TABLE ...');
  ///   await _initializeFts(db);
  /// }
  /// ```
  Future<void> _initializeFts(Database db) async {
    // Try FTS5 first (best performance)
    try {
      await _createFts5Tables(db);
      await _createFts5Triggers(db);
      setFtsVersion(5);
      debugPrint('FTS5 initialized successfully');
      return;
    } catch (e) {
      if (e.toString().contains('no such module')) {
        debugPrint('FTS5 not available, trying FTS4...');
      } else {
        // Unexpected error - rethrow to avoid silent failures
        rethrow;
      }
    }

    // Try FTS4 fallback (universal compatibility)
    try {
      await _createFts4Tables(db);
      await _createFts4Triggers(db);
      setFtsVersion(4);
      debugPrint('FTS4 initialized successfully');
      return;
    } catch (e) {
      if (e.toString().contains('no such module')) {
        debugPrint('FTS4 not available, disabling FTS');
      } else {
        // Unexpected error - rethrow to avoid silent failures
        rethrow;
      }
    }

    // FTS completely disabled - app will use LIKE-based search
    setFtsVersion(0);
    debugPrint('WARNING: FTS unavailable, using LIKE-based search');
  }
}
