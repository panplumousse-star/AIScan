import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

import '../security/secure_storage_service.dart';

/// Riverpod provider for [DatabaseHelper].
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  final secureStorage = ref.read(secureStorageServiceProvider);
  return DatabaseHelper(secureStorage: secureStorage);
});

/// Database helper class for managing encrypted SQLite database operations.
///
/// Uses SQLCipher for AES-256 encryption of all database contents including
/// metadata, OCR text, and full-text search indexes. The encryption key is
/// managed by [SecureStorageService] using platform secure storage
/// (Android KeyStore/iOS Keychain) - the same key used for file encryption.
///
/// Implements FTS5/FTS4 fallback strategy for full-text search capabilities.
/// Supports three modes:
/// - FTS5 (version 5): Best performance with rank ordering
/// - FTS4 (version 4): Universal compatibility fallback
/// - Disabled (version 0): LIKE-based search when FTS unavailable
///
/// ## Security
///
/// All sensitive data stored in the database is encrypted at rest:
/// - Document titles, descriptions, and metadata
/// - OCR-extracted text (may contain PII, financial data, medical records)
/// - Folder names and hierarchies
/// - Tags and search history
/// - Full-text search indexes (FTS virtual tables)
///
/// The database file is unreadable without the encryption password, which is
/// derived from the encryption key stored in platform secure storage.
class DatabaseHelper {
  /// Creates a [DatabaseHelper] with the required [SecureStorageService].
  DatabaseHelper({
    required SecureStorageService secureStorage,
  }) : _secureStorage = secureStorage;

  /// The secure storage service for database encryption key management.
  final SecureStorageService _secureStorage;

  static Database? _database;

  // Database configuration
  static const String _databaseName = 'aiscan.db';
  static const int _databaseVersion = 3;

  // Table names
  static const String tableDocuments = 'documents';
  static const String tableDocumentPages = 'document_pages';
  static const String tableDocumentsFts = 'documents_fts';
  static const String tableFolders = 'folders';
  static const String tableTags = 'tags';
  static const String tableDocumentTags = 'document_tags';
  static const String tableSignatures = 'signatures';
  static const String tableSearchHistory = 'search_history';

  // Column names for documents table
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDescription = 'description';
  static const String columnOcrText = 'ocr_text';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnFolderId = 'folder_id';
  static const String columnIsFavorite = 'is_favorite';
  static const String columnThumbnailPath = 'thumbnail_path';
  static const String columnFileSize = 'file_size';

  // Column names for document_pages table
  static const String columnDocumentId = 'document_id';
  static const String columnPageNumber = 'page_number';
  static const String columnFilePath = 'file_path';

  // Column names for document_tags table
  static const String columnTagId = 'tag_id';

  // Column names for folders table
  static const String columnName = 'name';
  static const String columnParentId = 'parent_id';

  // Column names for tags table
  static const String columnColor = 'color';

  // Column names for search_history table
  static const String columnQuery = 'query';
  static const String columnTimestamp = 'timestamp';
  static const String columnResultCount = 'result_count';

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

  /// Initializes the encrypted database using SQLCipher.
  ///
  /// Retrieves the encryption key from [SecureStorageService] and passes it
  /// to SQLCipher as the database password. This ensures all database contents
  /// are encrypted at rest using AES-256 encryption.
  ///
  /// The same encryption key is used for both file encryption and database
  /// encryption, providing consistent security across all stored data.
  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    final encryptionKey = await _secureStorage.getOrCreateEncryptionKey();
    debugPrint(
        'DatabaseHelper: Opening database with key length: ${encryptionKey.length}');
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      password: encryptionKey,
    );
  }

  /// Creates database tables and FTS indexes within the encrypted database.
  ///
  /// All tables, indexes, and FTS virtual tables are created inside the
  /// SQLCipher-encrypted database, ensuring all content is encrypted at rest.
  Future<void> _onCreate(Database db, int version) async {
    // Create folders table
    await db.execute('''
      CREATE TABLE $tableFolders (
        $columnId TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parent_id TEXT,
        color TEXT,
        icon TEXT,
        $columnIsFavorite INTEGER NOT NULL DEFAULT 0,
        $columnCreatedAt TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL
      )
    ''');

    // Create main documents table
    // Note: page files are stored in document_pages table (multi-page support)
    await db.execute('''
      CREATE TABLE $tableDocuments (
        $columnId TEXT PRIMARY KEY,
        $columnTitle TEXT NOT NULL,
        $columnDescription TEXT,
        $columnThumbnailPath TEXT,
        original_file_name TEXT,
        $columnFileSize INTEGER NOT NULL DEFAULT 0,
        mime_type TEXT,
        $columnOcrText TEXT,
        ocr_status TEXT DEFAULT 'pending',
        $columnCreatedAt TEXT NOT NULL,
        $columnUpdatedAt TEXT NOT NULL,
        $columnFolderId TEXT,
        $columnIsFavorite INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY ($columnFolderId) REFERENCES $tableFolders($columnId) ON DELETE SET NULL
      )
    ''');

    // Create document_pages table for multi-page support
    // Each page is stored as a separate encrypted PNG file
    await db.execute('''
      CREATE TABLE $tableDocumentPages (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnDocumentId TEXT NOT NULL,
        $columnPageNumber INTEGER NOT NULL,
        $columnFilePath TEXT NOT NULL,
        FOREIGN KEY ($columnDocumentId) REFERENCES $tableDocuments($columnId) ON DELETE CASCADE
      )
    ''');

    // Create tags table
    await db.execute('''
      CREATE TABLE $tableTags (
        $columnId TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        $columnCreatedAt TEXT NOT NULL
      )
    ''');

    // Create document_tags junction table
    await db.execute('''
      CREATE TABLE $tableDocumentTags (
        $columnDocumentId TEXT NOT NULL,
        $columnTagId TEXT NOT NULL,
        PRIMARY KEY ($columnDocumentId, $columnTagId),
        FOREIGN KEY ($columnDocumentId) REFERENCES $tableDocuments($columnId) ON DELETE CASCADE,
        FOREIGN KEY ($columnTagId) REFERENCES $tableTags($columnId) ON DELETE CASCADE
      )
    ''');

    // Create signatures table
    await db.execute('''
      CREATE TABLE $tableSignatures (
        $columnId TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        $columnFilePath TEXT NOT NULL,
        $columnCreatedAt TEXT NOT NULL
      )
    ''');

    // Create search_history table
    await db.execute('''
      CREATE TABLE $tableSearchHistory (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnQuery TEXT NOT NULL,
        $columnTimestamp TEXT NOT NULL,
        $columnResultCount INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create indices for common queries
    await db.execute(
        'CREATE INDEX idx_documents_folder ON $tableDocuments($columnFolderId)');
    await db.execute(
        'CREATE INDEX idx_documents_favorite ON $tableDocuments($columnIsFavorite)');
    await db.execute(
        'CREATE INDEX idx_documents_created ON $tableDocuments($columnCreatedAt)');
    await db.execute(
        'CREATE INDEX idx_document_pages_document ON $tableDocumentPages($columnDocumentId)');
    await db.execute(
        'CREATE UNIQUE INDEX idx_document_pages_order ON $tableDocumentPages($columnDocumentId, $columnPageNumber)');
    await db.execute(
        'CREATE INDEX idx_search_history_timestamp ON $tableSearchHistory($columnTimestamp)');

    // Initialize FTS tables and triggers with automatic fallback
    await _initializeFts(db);
  }

  /// Handles database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here

    // Migration from version 1 to 2: Add is_favorite column to folders table
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE $tableFolders ADD COLUMN $columnIsFavorite INTEGER NOT NULL DEFAULT 0
      ''');
    }

    // Migration from version 2 to 3: Add search_history table
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE $tableSearchHistory (
          $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnQuery TEXT NOT NULL,
          $columnTimestamp TEXT NOT NULL,
          $columnResultCount INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
          'CREATE INDEX idx_search_history_timestamp ON $tableSearchHistory($columnTimestamp)');
    }
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
    // Check FTS5 availability first (without creating table)
    if (await _isFtsModuleAvailable(db, 'fts5')) {
      try {
        await _createFts5Tables(db);
        await _createFts5Triggers(db);
        setFtsVersion(5);
        return;
      } on Object catch (_) {
        await _cleanupFts(db);
      }
    } else {}

    // Check FTS4 availability
    if (await _isFtsModuleAvailable(db, 'fts4')) {
      try {
        await _createFts4Tables(db);
        await _createFts4Triggers(db);
        setFtsVersion(4);
        return;
      } on Object catch (_) {
        await _cleanupFts(db);
      }
    }

    // FTS completely disabled - app will use LIKE-based search
    setFtsVersion(0);
  }

  /// Checks if an FTS module is available without creating a table.
  Future<bool> _isFtsModuleAvailable(Database db, String moduleName) async {
    try {
      // Query the compile_options to check for FTS support
      final result = await db.rawQuery('PRAGMA compile_options');
      final options =
          result.map((r) => r.values.first.toString().toUpperCase()).toList();

      if (moduleName == 'fts5') {
        return options
            .any((o) => o.contains('FTS5') || o.contains('ENABLE_FTS5'));
      } else if (moduleName == 'fts4') {
        // FTS4 is usually enabled with FTS3
        return options.any((o) =>
            o.contains('FTS4') ||
            o.contains('FTS3') ||
            o.contains('ENABLE_FTS3'));
      }
      return false;
    } on Object catch (_) {
      return false;
    }
  }

  /// Cleans up FTS tables and triggers after a failed initialization attempt.
  Future<void> _cleanupFts(Database db) async {
    try {
      await db.execute('DROP TRIGGER IF EXISTS documents_ai');
      await db.execute('DROP TRIGGER IF EXISTS documents_ad');
      await db.execute('DROP TRIGGER IF EXISTS documents_au');
      // Use DELETE FROM sqlite_master as fallback if DROP TABLE fails
      try {
        await db.execute('DROP TABLE IF EXISTS $tableDocumentsFts');
      } on Object catch (_) {
        try {
          await db.execute(
              "DELETE FROM sqlite_master WHERE name = '$tableDocumentsFts'");
        } on Object {
          // Cleanup failed, ignore
        }
      }
    } on Object catch (_) {
      // FTS cleanup error (ignored)
    }
  }

  /// Searches documents using FTS5 full-text search with rank ordering.
  ///
  /// FTS5 provides the best search performance with:
  /// - `MATCH` clause for full-text queries
  /// - Built-in `rank` column for relevance-based ordering
  /// - Automatic tokenization and stemming
  ///
  /// The query is escaped to prevent FTS5 syntax errors from special characters.
  /// Results are returned ordered by relevance (best matches first).
  ///
  /// Parameters:
  /// - [db]: The database instance to query
  /// - [query]: The search query string (will be escaped for FTS5 syntax)
  ///
  /// Returns a list of document maps matching the search query, ordered by relevance.
  ///
  /// Example:
  /// ```dart
  /// final results = await _searchWithFts5(db, 'flutter tutorial');
  /// // Returns documents containing 'flutter' AND 'tutorial', ranked by relevance
  /// ```
  Future<List<Map<String, dynamic>>> _searchWithFts5(
    Database db,
    String query,
  ) async {
    // Escape special FTS5 characters to prevent syntax errors
    final escapedQuery = _escapeFtsQuery(query);

    // FTS5 query with rank ordering for relevance-based results
    // JOIN with main table to get all document columns
    // ORDER BY rank ASC because FTS5 rank values are negative (closer to 0 = better match)
    final results = await db.rawQuery('''
      SELECT d.*
      FROM $tableDocuments d
      INNER JOIN $tableDocumentsFts fts ON d.rowid = fts.rowid
      WHERE $tableDocumentsFts MATCH ?
      ORDER BY fts.rank
    ''', [escapedQuery]);

    return results;
  }

  /// Searches documents using FTS4 full-text search without rank ordering.
  ///
  /// FTS4 provides universal compatibility with older Android devices:
  /// - `MATCH` clause for full-text queries
  /// - Uses `docid` as the implicit rowid reference
  /// - No built-in `rank` column (results ordered by creation date instead)
  ///
  /// The query is escaped to prevent FTS4 syntax errors from special characters.
  /// Results are returned ordered by creation date (most recent first) since
  /// FTS4 does not provide built-in relevance scoring like FTS5's rank.
  ///
  /// Parameters:
  /// - [db]: The database instance to query
  /// - [query]: The search query string (will be escaped for FTS4 syntax)
  ///
  /// Returns a list of document maps matching the search query, ordered by creation date.
  ///
  /// Example:
  /// ```dart
  /// final results = await _searchWithFts4(db, 'flutter tutorial');
  /// // Returns documents containing 'flutter' AND 'tutorial', ordered by date
  /// ```
  Future<List<Map<String, dynamic>>> _searchWithFts4(
    Database db,
    String query,
  ) async {
    // Escape special FTS4 characters to prevent syntax errors
    final escapedQuery = _escapeFtsQuery(query);

    // FTS4 query without rank ordering (FTS4 has no built-in rank)
    // JOIN with main table to get all document columns
    // ORDER BY created_at DESC for most recent first (no relevance ranking available)
    final results = await db.rawQuery('''
      SELECT d.*
      FROM $tableDocuments d
      INNER JOIN $tableDocumentsFts fts ON d.rowid = fts.docid
      WHERE $tableDocumentsFts MATCH ?
      ORDER BY d.$columnCreatedAt DESC
    ''', [escapedQuery]);

    return results;
  }

  /// Searches documents using LIKE-based queries when FTS is unavailable.
  ///
  /// This is the fallback search method when neither FTS5 nor FTS4 is available.
  /// It provides basic search functionality using SQL LIKE patterns:
  /// - Each search term is converted to a '%term%' pattern
  /// - Multiple terms are combined with AND for all-terms matching
  /// - Searches across title, description, and OCR text columns
  ///
  /// LIKE-based search has limitations compared to FTS:
  /// - No relevance ranking (results ordered by creation date instead)
  /// - Case-insensitive matching depends on SQLite collation
  /// - Slower performance on large datasets (no index optimization)
  ///
  /// Parameters:
  /// - [db]: The database instance to query
  /// - [query]: The search query string
  ///
  /// Returns a list of document maps matching the search query, ordered by creation date.
  ///
  /// Example:
  /// ```dart
  /// final results = await _searchWithLike(db, 'flutter tutorial');
  /// // Returns documents where title, description, or OCR text contains both terms
  /// ```
  Future<List<Map<String, dynamic>>> _searchWithLike(
    Database db,
    String query,
  ) async {
    // Split query into terms and filter empty strings
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    if (terms.isEmpty) {
      return [];
    }

    // Build conditions for each term across all searchable columns
    final conditions = <String>[];
    final args = <dynamic>[];

    for (final term in terms) {
      // Escape LIKE special characters (%, _) in the term
      final escapedTerm = term.replaceAll('%', r'\%').replaceAll('_', r'\_');
      final likePattern = '%$escapedTerm%';

      // Each term must match at least one column (OR within term)
      // All terms must be found (AND between terms)
      conditions.add('''
        ($columnTitle LIKE ? ESCAPE '\\' OR
         $columnDescription LIKE ? ESCAPE '\\' OR
         $columnOcrText LIKE ? ESCAPE '\\')
      ''');

      // Add the pattern three times (once for each column)
      args.addAll([likePattern, likePattern, likePattern]);
    }

    // Combine all term conditions with AND
    final whereClause = conditions.join(' AND ');

    // Query documents with LIKE matching, ordered by creation date (most recent first)
    final results = await db.rawQuery('''
      SELECT *
      FROM $tableDocuments
      WHERE $whereClause
      ORDER BY $columnCreatedAt DESC
    ''', args);

    return results;
  }

  /// Escapes special characters in FTS queries to prevent syntax errors.
  ///
  /// FTS5 and FTS4 have special characters that can cause query syntax errors:
  /// - `"` (double quote) - phrase queries
  /// - `*` (asterisk) - prefix queries
  /// - `^` (caret) - boost operator (FTS5 only)
  /// - `-` (minus) - exclusion operator
  /// - `+` (plus) - required term operator
  ///
  /// This method wraps each search term in double quotes to treat them as literals.
  ///
  /// Parameters:
  /// - [query]: The raw search query from user input
  ///
  /// Returns an escaped query string safe for FTS MATCH operations.
  String _escapeFtsQuery(String query) {
    // Split query into terms and wrap each in double quotes
    // This treats each term as a literal phrase, escaping special characters
    final terms = query.trim().split(RegExp(r'\s+'));
    final escapedTerms = terms
        .where((term) => term.isNotEmpty)
        .map((term) => '"${term.replaceAll('"', '""')}"')
        .toList();

    return escapedTerms.join(' ');
  }

  /// Searches documents using the best available search method.
  ///
  /// Dispatches to the appropriate search implementation based on [_ftsVersion]:
  /// - FTS5 (version 5): Uses [_searchWithFts5] for relevance-ranked results
  /// - FTS4 (version 4): Uses [_searchWithFts4] for date-ordered results
  /// - Disabled (version 0): Uses [_searchWithLike] for basic LIKE-based search
  ///
  /// This method provides a unified search interface regardless of the underlying
  /// FTS capability, ensuring consistent behavior across all Android devices.
  ///
  /// Parameters:
  /// - [query]: The search query string
  ///
  /// Returns a list of document IDs matching the search query.
  /// Results are ordered by:
  /// - Relevance (FTS5): Best matches first
  /// - Creation date (FTS4/LIKE): Most recent first
  ///
  /// Returns an empty list if the query is empty or contains only whitespace.
  Future<List<String>> searchDocuments(String query) async {
    // Return empty list for empty queries
    if (query.trim().isEmpty) {
      return [];
    }

    final db = await database;

    List<Map<String, dynamic>> results;
    // Dispatch to appropriate search method based on FTS version
    switch (_ftsVersion) {
      case 5:
        results = await _searchWithFts5(db, query);
      case 4:
        results = await _searchWithFts4(db, query);
      default:
        // FTS disabled (version 0) - use LIKE-based search
        results = await _searchWithLike(db, query);
    }

    // Extract and return only the document IDs
    return results.map((row) => row[columnId] as String).toList();
  }

  /// Rebuilds the FTS index to optimize search performance.
  ///
  /// FTS indexes can become fragmented over time as documents are added,
  /// updated, and deleted. Rebuilding the index optimizes storage and
  /// can improve search performance.
  ///
  /// Behavior based on [_ftsVersion]:
  /// - FTS5 (version 5): Executes 'rebuild' command to optimize index
  /// - FTS4 (version 4): Executes 'rebuild' command to optimize index
  /// - Disabled (version 0): No-op, returns immediately (no index to rebuild)
  ///
  /// This operation can be slow for large datasets and should typically
  /// be run during app idle time or maintenance windows.
  ///
  /// Example:
  /// ```dart
  /// final helper = DatabaseHelper();
  /// await helper.rebuildFtsIndex();
  /// ```
  Future<void> rebuildFtsIndex() async {
    // No FTS index to rebuild in disabled mode
    if (_ftsVersion == 0) {
      return;
    }

    final db = await database;

    // Both FTS5 and FTS4 support the 'rebuild' command
    // FTS5/FTS4 syntax: INSERT INTO fts_table(fts_table) VALUES('rebuild')
    // This optimizes the FTS index by merging segments and removing deleted content
    if (_ftsVersion == 5 || _ftsVersion == 4) {
      await db.execute('''
        INSERT INTO $tableDocumentsFts($tableDocumentsFts) VALUES('rebuild')
      ''');
    }
  }

  // ============================================================
  // CRUD Methods
  // ============================================================

  /// Inserts a row into the specified table.
  Future<int> insert(String table, Map<String, dynamic> values) async {
    final db = await database;
    return db.insert(table, values);
  }

  /// Queries rows from the specified table.
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Updates rows in the specified table.
  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  /// Deletes rows from the specified table.
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Gets a single row by ID from the specified table.
  Future<Map<String, dynamic>?> getById(String table, String id) async {
    final db = await database;
    final results = await db.query(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Counts rows in the specified table.
  Future<int> count(String table,
      {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table${where != null ? ' WHERE $where' : ''}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Executes a raw SQL query.
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, arguments);
  }

  /// Executes operations within a transaction.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return db.transaction(action);
  }

  /// Initializes the database (call this at app startup).
  Future<void> initialize() async {
    await database;
  }

  /// Checks if a row with the given ID exists in the specified table.
  Future<bool> exists(String table, String id) async {
    final db = await database;
    final result = await db.query(
      table,
      columns: [columnId],
      where: '$columnId = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Whether full-text search is available.
  bool get isFtsAvailable => _ftsVersion > 0;

  /// Whether the database has been initialized.
  bool get isInitialized => _database != null;

  /// Gets all tags from the database.
  Future<List<Map<String, dynamic>>> getAllTags({String? orderBy}) async {
    final db = await database;
    return db.query(
      tableTags,
      orderBy: orderBy ?? '$columnName ASC',
    );
  }

  /// Gets all folders from the database.
  Future<List<Map<String, dynamic>>> getAllFolders({String? orderBy}) async {
    final db = await database;
    return db.query(
      tableFolders,
      orderBy: orderBy ?? '$columnName ASC',
    );
  }

  // ============================================================
  // Document Pages CRUD Methods
  // ============================================================

  /// Gets all pages for a document, ordered by page number.
  Future<List<Map<String, dynamic>>> getDocumentPages(String documentId) async {
    final db = await database;
    return db.query(
      tableDocumentPages,
      where: '$columnDocumentId = ?',
      whereArgs: [documentId],
      orderBy: '$columnPageNumber ASC',
    );
  }

  /// Gets the file paths for all pages of a document, ordered by page number.
  Future<List<String>> getDocumentPagePaths(String documentId) async {
    final pages = await getDocumentPages(documentId);
    return pages.map((p) => p[columnFilePath] as String).toList();
  }

  /// Gets the file paths for all pages of multiple documents in a single query.
  ///
  /// This method eliminates N+1 query problems by fetching all pages for multiple
  /// documents in one database query using an SQL IN clause.
  ///
  /// Parameters:
  /// - [documentIds]: List of document IDs to fetch page paths for
  ///
  /// Returns a Map where:
  /// - Key: document ID
  /// - Value: List of file paths ordered by page number
  ///
  /// Documents with no pages will have an empty list in the result map.
  ///
  /// Example:
  /// ```dart
  /// final paths = await getBatchDocumentPagePaths(['doc1', 'doc2', 'doc3']);
  /// // Returns: {'doc1': ['path1', 'path2'], 'doc2': ['path3'], 'doc3': []}
  /// ```
  Future<Map<String, List<String>>> getBatchDocumentPagePaths(
    List<String> documentIds,
  ) async {
    // Return empty map for empty input
    if (documentIds.isEmpty) {
      return {};
    }

    final db = await database;

    // Initialize result map with empty lists for all document IDs
    final result = <String, List<String>>{};
    for (final id in documentIds) {
      result[id] = [];
    }

    // Build SQL IN clause with placeholders
    final placeholders = List.filled(documentIds.length, '?').join(',');

    // Query all pages for the given document IDs in a single query
    final pages = await db.rawQuery('''
      SELECT $columnDocumentId, $columnFilePath
      FROM $tableDocumentPages
      WHERE $columnDocumentId IN ($placeholders)
      ORDER BY $columnDocumentId, $columnPageNumber ASC
    ''', documentIds);

    // Group pages by document ID
    for (final page in pages) {
      final docId = page[columnDocumentId] as String?;
      final filePath = page[columnFilePath] as String?;
      if (docId != null && filePath != null && result.containsKey(docId)) {
        result[docId]!.add(filePath);
      }
    }

    return result;
  }

  /// Gets a single page by document ID and page number.
  Future<Map<String, dynamic>?> getDocumentPage(
    String documentId,
    int pageNumber,
  ) async {
    final db = await database;
    final results = await db.query(
      tableDocumentPages,
      where: '$columnDocumentId = ? AND $columnPageNumber = ?',
      whereArgs: [documentId, pageNumber],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Inserts a page for a document.
  Future<int> insertDocumentPage({
    required String documentId,
    required int pageNumber,
    required String filePath,
  }) async {
    final db = await database;
    return db.insert(tableDocumentPages, {
      columnDocumentId: documentId,
      columnPageNumber: pageNumber,
      columnFilePath: filePath,
    });
  }

  /// Inserts multiple pages for a document in a transaction.
  Future<void> insertDocumentPages(
    String documentId,
    List<String> filePaths,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < filePaths.length; i++) {
        await txn.insert(tableDocumentPages, {
          columnDocumentId: documentId,
          columnPageNumber: i,
          columnFilePath: filePaths[i],
        });
      }
    });
  }

  /// Deletes all pages for a document.
  Future<int> deleteDocumentPages(String documentId) async {
    final db = await database;
    return db.delete(
      tableDocumentPages,
      where: '$columnDocumentId = ?',
      whereArgs: [documentId],
    );
  }

  /// Updates a page's file path.
  Future<int> updateDocumentPagePath({
    required String documentId,
    required int pageNumber,
    required String newFilePath,
  }) async {
    final db = await database;
    return db.update(
      tableDocumentPages,
      {columnFilePath: newFilePath},
      where: '$columnDocumentId = ? AND $columnPageNumber = ?',
      whereArgs: [documentId, pageNumber],
    );
  }

  /// Gets the page count for a document.
  Future<int> getDocumentPageCount(String documentId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableDocumentPages WHERE $columnDocumentId = ?',
      [documentId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============================================================
  // Document Tags CRUD Methods
  // ============================================================

  /// Gets the tag IDs for multiple documents in a single query.
  ///
  /// This method eliminates N+1 query problems by fetching all tags for multiple
  /// documents in one database query using an SQL IN clause.
  ///
  /// Parameters:
  /// - [documentIds]: List of document IDs to fetch tag IDs for
  ///
  /// Returns a Map where:
  /// - Key: document ID
  /// - Value: List of tag IDs
  ///
  /// Documents with no tags will have an empty list in the result map.
  ///
  /// Example:
  /// ```dart
  /// final tags = await getBatchDocumentTags(['doc1', 'doc2', 'doc3']);
  /// // Returns: {'doc1': ['tag1', 'tag2'], 'doc2': ['tag1'], 'doc3': []}
  /// ```
  Future<Map<String, List<String>>> getBatchDocumentTags(
    List<String> documentIds,
  ) async {
    // Return empty map for empty input
    if (documentIds.isEmpty) {
      return {};
    }

    final db = await database;

    // Initialize result map with empty lists for all document IDs
    final result = <String, List<String>>{};
    for (final id in documentIds) {
      result[id] = [];
    }

    // Build SQL IN clause with placeholders
    final placeholders = List.filled(documentIds.length, '?').join(',');

    // Query all tags for the given document IDs in a single query
    final tags = await db.rawQuery('''
      SELECT $columnDocumentId, $columnTagId
      FROM $tableDocumentTags
      WHERE $columnDocumentId IN ($placeholders)
      ORDER BY $columnDocumentId
    ''', documentIds);

    // Group tags by document ID
    for (final tag in tags) {
      final docId = tag[columnDocumentId] as String?;
      final tagId = tag[columnTagId] as String?;
      if (docId != null && tagId != null && result.containsKey(docId)) {
        result[docId]!.add(tagId);
      }
    }

    return result;
  }

  // ============================================================
  // Search History CRUD Methods
  // ============================================================

  /// Inserts a new search history entry.
  Future<int> insertSearchHistory({
    required String query,
    required String timestamp,
    required int resultCount,
  }) async {
    final db = await database;
    return db.insert(tableSearchHistory, {
      columnQuery: query,
      columnTimestamp: timestamp,
      columnResultCount: resultCount,
    });
  }

  /// Gets all search history entries, ordered by timestamp descending.
  Future<List<Map<String, dynamic>>> getSearchHistory({
    int? limit,
    String? orderBy,
  }) async {
    final db = await database;
    return db.query(
      tableSearchHistory,
      orderBy: orderBy ?? '$columnTimestamp DESC',
      limit: limit,
    );
  }

  /// Deletes a specific search history entry by ID.
  Future<int> deleteSearchHistory(int id) async {
    final db = await database;
    return db.delete(
      tableSearchHistory,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  /// Deletes all search history entries.
  Future<int> clearSearchHistory() async {
    final db = await database;
    return db.delete(tableSearchHistory);
  }
}
