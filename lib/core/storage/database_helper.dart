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
}
