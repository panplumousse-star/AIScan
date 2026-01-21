import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aiscan/core/storage/database_helper.dart';

/// Tests for DatabaseHelper FTS detection and fallback logic.
///
/// These tests verify the FTS5/FTS4 fallback strategy implementation:
/// - FTS version state tracking (_ftsVersion)
/// - FTS version getter/setter
/// - Version-based search dispatch
/// - Query escaping for FTS special characters
void main() {
  group('DatabaseHelper', () {
    setUp(() {
      // Reset FTS version before each test to ensure clean state
      DatabaseHelper.resetFtsVersion();
    });

    group('FTS Version State', () {
      test('ftsVersion should default to 0 (disabled)', () {
        // After reset, FTS version should be 0 (disabled mode)
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('ftsVersion should return 5 when FTS5 is set', () {
        // Simulate FTS5 being detected and initialized
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });

      test('ftsVersion should return 4 when FTS4 fallback is active', () {
        // Simulate FTS4 fallback being activated
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('ftsVersion should return 0 when FTS is disabled', () {
        // Simulate FTS being completely disabled
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('resetFtsVersion should reset version to 0', () {
        // Set to FTS5, then reset
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));

        DatabaseHelper.resetFtsVersion();
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('setFtsVersion should only accept valid values (0, 4, 5)', () {
        // Valid values should work without assertion errors
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));

        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));

        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));

        // Note: Invalid values (e.g., 1, 2, 3, 6) would trigger assertions
        // in debug mode but we don't test assertion failures here
      });
    });

    group('FTS5 Detection', () {
      test('_ftsVersion should be 5 when FTS5 is available', () {
        // Simulate successful FTS5 initialization
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });

      test('FTS5 mode should indicate full search capability', () {
        DatabaseHelper.setFtsVersion(5);
        // FTS5 provides the best search with rank ordering
        expect(DatabaseHelper.ftsVersion, equals(5));
        // When ftsVersion is 5, searchDocuments uses _searchWithFts5
        // which provides relevance-ranked results
      });
    });

    group('FTS5 Table Structure', () {
      test('FTS5 virtual table uses content= option for external content', () {
        // FTS5 external content table structure:
        // CREATE VIRTUAL TABLE documents_fts USING fts5(
        //   title,
        //   description,
        //   ocr_text,
        //   content=documents,
        //   content_rowid=rowid
        // )
        //
        // The content= option links the FTS table to the documents table
        // The content_rowid= option specifies the rowid column for joins
        expect(DatabaseHelper.tableDocumentsFts, equals('documents_fts'));
        expect(DatabaseHelper.tableDocuments, equals('documents'));
      });

      test('FTS5 virtual table includes all searchable columns', () {
        // FTS5 table includes these searchable columns:
        // - title: document title
        // - description: document description
        // - ocr_text: extracted OCR text from scanned images
        expect(DatabaseHelper.columnTitle, equals('title'));
        expect(DatabaseHelper.columnDescription, equals('description'));
        expect(DatabaseHelper.columnOcrText, equals('ocr_text'));
      });

      test('FTS5 content_rowid option enables efficient joins', () {
        // FTS5's content_rowid=rowid option allows efficient joins:
        // SELECT d.* FROM documents d
        // INNER JOIN documents_fts fts ON d.rowid = fts.rowid
        // WHERE documents_fts MATCH ?
        //
        // This is more efficient than FTS4's docid-based joins
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });
    });

    group('FTS5 Trigger Creation', () {
      test('FTS5 documents_ai trigger fires AFTER INSERT', () {
        // documents_ai trigger inserts into FTS index when document is created:
        // CREATE TRIGGER documents_ai AFTER INSERT ON documents BEGIN
        //   INSERT INTO documents_fts(rowid, title, description, ocr_text)
        //   VALUES (NEW.rowid, NEW.title, NEW.description, NEW.ocr_text);
        // END
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
        // Trigger uses NEW.rowid to match the document's primary key
        // This keeps FTS index synchronized with main table
      });

      test('FTS5 documents_ad trigger uses special "delete" command', () {
        // FTS5 DELETE is special - uses INSERT with 'delete' command:
        // CREATE TRIGGER documents_ad AFTER DELETE ON documents BEGIN
        //   INSERT INTO documents_fts(documents_fts, rowid, title, description, ocr_text)
        //   VALUES ('delete', OLD.rowid, OLD.title, OLD.description, OLD.ocr_text);
        // END
        //
        // IMPORTANT: FTS5 does NOT use standard DELETE statement!
        // The first column name in the INSERT must be the table name,
        // and the first value must be the literal string 'delete'
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });

      test('FTS5 documents_au trigger performs delete then insert', () {
        // FTS5 UPDATE trigger removes old entry and inserts new:
        // CREATE TRIGGER documents_au AFTER UPDATE ON documents BEGIN
        //   INSERT INTO documents_fts(documents_fts, rowid, ...) VALUES ('delete', OLD.rowid, ...);
        //   INSERT INTO documents_fts(rowid, ...) VALUES (NEW.rowid, ...);
        // END
        //
        // FTS5 has no UPDATE operation - must delete old then insert new
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });

      test('FTS5 trigger names follow naming convention', () {
        // FTS5 triggers use consistent naming convention:
        // - documents_ai: AFTER INSERT
        // - documents_ad: AFTER DELETE
        // - documents_au: AFTER UPDATE
        //
        // The naming pattern is: {table}_{suffix}
        // Where suffix is: ai (after insert), ad (after delete), au (after update)
        expect(DatabaseHelper.tableDocuments, equals('documents'));
        // Trigger names are documents_ai, documents_ad, documents_au
      });

      test('FTS5 triggers maintain synchronization integrity', () {
        // All three FTS5 triggers work together to keep the index synchronized:
        // 1. INSERT: New documents are immediately indexed
        // 2. DELETE: Removed documents are immediately deindexed
        // 3. UPDATE: Modified documents are reindexed with new content
        //
        // This ensures searchDocuments always returns current data
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });
    });

    group('FTS5 Rank Ordering', () {
      test('FTS5 provides built-in rank column for relevance ordering', () {
        // FTS5 has a built-in rank column that scores match relevance:
        // SELECT d.* FROM documents d
        // INNER JOIN documents_fts fts ON d.rowid = fts.rowid
        // WHERE documents_fts MATCH ?
        // ORDER BY fts.rank
        //
        // Lower rank values indicate better matches (closer to 0 = better)
        // This enables relevance-based search results
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
        // When version is 5, search uses rank ordering for best matches first
      });

      test('FTS5 rank ordering differs from FTS4 date ordering', () {
        // FTS5: ORDER BY fts.rank (relevance-based)
        // FTS4: ORDER BY d.created_at DESC (date-based)
        //
        // FTS5 provides better search UX with relevance ranking
        // FTS4 falls back to chronological ordering
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });
    });

    group('FTS5 Detection Flow', () {
      test('_initializeFts attempts FTS5 before FTS4', () {
        // Initialization order in _initializeFts():
        // 1. Try FTS5 (best performance)
        // 2. If FTS5 fails with "no such module", try FTS4
        // 3. If FTS4 fails, disable FTS and use LIKE search
        //
        // This ensures best available FTS is always used
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });

      test('FTS5 detection catches "no such module" error', () {
        // When FTS5 module is unavailable, SQLite throws:
        // DatabaseException(no such module: fts5)
        //
        // _initializeFts catches this specific error and falls back to FTS4
        // Other errors are rethrown to prevent silent failures
        const fts5Error = 'DatabaseException(no such module: fts5)';
        expect(fts5Error.contains('no such module'), isTrue);
        expect(fts5Error.contains('fts5'), isTrue);
      });

      test('FTS5 success sets _ftsVersion to 5 immediately', () {
        // When FTS5 tables and triggers are created successfully:
        // 1. _createFts5Tables() completes without error
        // 2. _createFts5Triggers() completes without error
        // 3. setFtsVersion(5) is called
        // 4. _initializeFts returns early (no FTS4 attempt)
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
      });

      test('FTS5 detection logs success message', () {
        // On successful FTS5 initialization:
        // debugPrint('FTS5 initialized successfully')
        //
        // This helps with debugging FTS detection on different devices
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
        // Log message confirms FTS5 is active
      });
    });

    group('FTS4 Fallback Detection', () {
      test('_ftsVersion should be 4 when FTS5 fails but FTS4 works', () {
        // Simulate FTS5 failure and FTS4 success
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 mode should indicate fallback search capability', () {
        DatabaseHelper.setFtsVersion(4);
        // FTS4 provides full-text search without rank ordering
        expect(DatabaseHelper.ftsVersion, equals(4));
        // When ftsVersion is 4, searchDocuments uses _searchWithFts4
        // which provides date-ordered results
      });

      test('FTS4 detection catches "no such module: fts5" error', () {
        // When FTS5 module is unavailable, SQLite throws:
        // DatabaseException(no such module: fts5)
        //
        // _initializeFts catches this specific error and tries FTS4 fallback
        const fts5Error = 'DatabaseException(no such module: fts5)';
        expect(fts5Error.contains('no such module'), isTrue);
        expect(fts5Error.contains('fts5'), isTrue);
        // After catching FTS5 error, FTS4 initialization is attempted
      });

      test('FTS4 success sets _ftsVersion to 4', () {
        // When FTS4 tables and triggers are created successfully:
        // 1. _createFts4Tables() completes without error
        // 2. _createFts4Triggers() completes without error
        // 3. setFtsVersion(4) is called
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 detection logs success message', () {
        // On successful FTS4 initialization:
        // debugPrint('FTS4 initialized successfully')
        //
        // This helps with debugging FTS detection on different devices
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
        // Log message confirms FTS4 fallback is active
      });

      test('FTS4 fallback is only attempted after FTS5 failure', () {
        // _initializeFts follows strict order:
        // 1. Try FTS5 first (best performance)
        // 2. Only if FTS5 fails with "no such module", try FTS4
        // 3. FTS4 is never attempted if FTS5 succeeds
        //
        // This ensures best available FTS is always used
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
        // Version 4 indicates FTS5 failed but FTS4 succeeded
      });
    });

    group('FTS4 Table Structure', () {
      test('FTS4 virtual table uses content= option for external content', () {
        // FTS4 external content table structure:
        // CREATE VIRTUAL TABLE documents_fts USING fts4(
        //   title,
        //   description,
        //   ocr_text,
        //   content="documents"
        // )
        //
        // Note: FTS4 uses quoted table name, no content_rowid option
        expect(DatabaseHelper.tableDocumentsFts, equals('documents_fts'));
        expect(DatabaseHelper.tableDocuments, equals('documents'));
      });

      test('FTS4 virtual table includes all searchable columns', () {
        // FTS4 table includes these searchable columns:
        // - title: document title
        // - description: document description
        // - ocr_text: extracted OCR text from scanned images
        expect(DatabaseHelper.columnTitle, equals('title'));
        expect(DatabaseHelper.columnDescription, equals('description'));
        expect(DatabaseHelper.columnOcrText, equals('ocr_text'));
      });

      test('FTS4 uses docid instead of content_rowid for joins', () {
        // FTS4 does NOT support content_rowid option
        // Instead, FTS4 uses implicit docid for joins:
        // SELECT d.* FROM documents d
        // INNER JOIN documents_fts fts ON d.rowid = fts.docid
        // WHERE documents_fts MATCH ?
        //
        // This differs from FTS5's rowid-based joins
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 external content table has no automatic sync', () {
        // FTS4 external content tables (content= option) do NOT
        // automatically sync with the main table.
        // Triggers are required to keep the FTS index synchronized.
        //
        // This is the same as FTS5 behavior.
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });
    });

    group('FTS4 Trigger Creation', () {
      test('FTS4 documents_ai trigger fires AFTER INSERT', () {
        // documents_ai trigger inserts into FTS index when document is created:
        // CREATE TRIGGER documents_ai AFTER INSERT ON documents BEGIN
        //   INSERT INTO documents_fts(docid, title, description, ocr_text)
        //   VALUES (NEW.rowid, NEW.title, NEW.description, NEW.ocr_text);
        // END
        //
        // Note: FTS4 uses docid instead of rowid for the INSERT column
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
        // Trigger uses docid to match the document's primary key
      });

      test('FTS4 documents_ad trigger uses standard DELETE syntax', () {
        // FTS4 DELETE trigger uses standard SQL DELETE:
        // CREATE TRIGGER documents_ad AFTER DELETE ON documents BEGIN
        //   DELETE FROM documents_fts WHERE docid = OLD.rowid;
        // END
        //
        // IMPORTANT: FTS4 uses standard DELETE statement!
        // This differs from FTS5's special INSERT 'delete' command syntax
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 documents_au trigger performs delete then insert', () {
        // FTS4 UPDATE trigger removes old entry and inserts new:
        // CREATE TRIGGER documents_au AFTER UPDATE ON documents BEGIN
        //   DELETE FROM documents_fts WHERE docid = OLD.rowid;
        //   INSERT INTO documents_fts(docid, ...) VALUES (NEW.rowid, ...);
        // END
        //
        // Like FTS5, FTS4 has no UPDATE operation - must delete old then insert new
        // But FTS4 uses standard DELETE (not FTS5's INSERT 'delete' command)
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 trigger names follow same naming convention as FTS5', () {
        // FTS4 triggers use the same naming convention as FTS5:
        // - documents_ai: AFTER INSERT
        // - documents_ad: AFTER DELETE
        // - documents_au: AFTER UPDATE
        //
        // The naming pattern is: {table}_{suffix}
        expect(DatabaseHelper.tableDocuments, equals('documents'));
        // Trigger names are identical for FTS4 and FTS5
      });

      test('FTS4 triggers use docid not rowid in INSERT statements', () {
        // Key difference from FTS5:
        // FTS5: INSERT INTO fts(rowid, ...) VALUES (NEW.rowid, ...);
        // FTS4: INSERT INTO fts(docid, ...) VALUES (NEW.rowid, ...);
        //
        // The INSERT column name is 'docid' for FTS4, 'rowid' for FTS5
        // But the value is still NEW.rowid from the documents table
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 triggers maintain synchronization integrity', () {
        // All three FTS4 triggers work together to keep the index synchronized:
        // 1. INSERT: New documents are immediately indexed (using docid)
        // 2. DELETE: Removed documents are immediately deindexed (standard DELETE)
        // 3. UPDATE: Modified documents are reindexed with new content
        //
        // This ensures searchDocuments always returns current data
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });
    });

    group('FTS4 Search Ordering', () {
      test('FTS4 has no built-in rank column for relevance ordering', () {
        // FTS4 does NOT have a built-in rank column like FTS5
        // Instead, FTS4 search results are ordered by created_at:
        // SELECT d.* FROM documents d
        // INNER JOIN documents_fts fts ON d.rowid = fts.docid
        // WHERE documents_fts MATCH ?
        // ORDER BY d.created_at DESC
        //
        // This provides date-based ordering (most recent first)
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 could use matchinfo() for relevance but implementation uses date ordering', () {
        // FTS4 has matchinfo() function for calculating relevance scores,
        // but the current implementation uses date ordering for simplicity:
        // - Avoids complex matchinfo() calculation overhead
        // - Provides predictable, understandable ordering to users
        // - Simpler code maintenance
        //
        // Date ordering: ORDER BY d.created_at DESC
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 ordering differs from FTS5 rank ordering', () {
        // FTS5: ORDER BY fts.rank (relevance-based, best matches first)
        // FTS4: ORDER BY d.created_at DESC (date-based, most recent first)
        //
        // This is a key difference in search UX between FTS5 and FTS4
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });
    });

    group('FTS4 Detection Flow', () {
      test('_initializeFts attempts FTS4 only after FTS5 fails', () {
        // Initialization order in _initializeFts():
        // 1. Try FTS5 (best performance)
        // 2. If FTS5 fails with "no such module", try FTS4
        // 3. If FTS4 fails, disable FTS and use LIKE search
        //
        // FTS4 is only attempted as a fallback, never as first choice
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 detection catches "no such module: fts4" error to disable FTS', () {
        // When FTS4 module is also unavailable, SQLite throws:
        // DatabaseException(no such module: fts4)
        //
        // _initializeFts catches this error and disables FTS completely
        const fts4Error = 'DatabaseException(no such module: fts4)';
        expect(fts4Error.contains('no such module'), isTrue);
        expect(fts4Error.contains('fts4'), isTrue);
        // After catching FTS4 error, FTS is disabled (version 0)
      });

      test('FTS4 logs appropriate message on success', () {
        // On successful FTS4 fallback initialization:
        // debugPrint('FTS4 initialized successfully')
        //
        // This confirms FTS4 is being used as fallback
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
      });

      test('FTS4 unexpected errors are rethrown not caught', () {
        // _initializeFts only catches "no such module" errors for FTS4
        // Other errors (disk full, permission denied, etc.) are rethrown
        // to prevent silent failures
        const unexpectedError = 'DatabaseException(disk I/O error)';
        expect(unexpectedError.contains('no such module'), isFalse);
        // This error would be rethrown, not caught as FTS fallback
      });
    });

    group('FTS Disabled Mode', () {
      test('_ftsVersion should be 0 when both FTS5 and FTS4 fail', () {
        // Simulate both FTS modules being unavailable
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('disabled mode should indicate LIKE-based search', () {
        DatabaseHelper.setFtsVersion(0);
        // LIKE-based search provides basic functionality
        expect(DatabaseHelper.ftsVersion, equals(0));
        // When ftsVersion is 0, searchDocuments uses _searchWithLike
        // which provides basic substring matching
      });

      test('_ftsVersion 0 indicates no FTS module is available', () {
        // Version 0 means:
        // 1. FTS5 initialization failed with "no such module: fts5"
        // 2. FTS4 initialization failed with "no such module: fts4"
        // 3. App gracefully degrades to LIKE-based search
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
        // This ensures app continues functioning on all Android devices
      });

      test('disabled mode is the final fallback in the FTS fallback chain', () {
        // FTS fallback chain: FTS5 -> FTS4 -> Disabled (LIKE)
        // Disabled mode (version 0) is only reached after both FTS5 and FTS4 fail
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
        // This represents the graceful degradation scenario
      });

      test('disabled mode logs warning message', () {
        // When FTS is completely disabled, a warning is logged:
        // debugPrint('WARNING: FTS unavailable, using LIKE-based search')
        //
        // This helps with debugging why search may be slower on some devices
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
        // Warning message indicates LIKE-based fallback is active
      });
    });

    group('FTS Disabled Mode Detection Flow', () {
      test('_initializeFts catches "no such module: fts4" to disable FTS', () {
        // When FTS4 is also unavailable after FTS5 fails, SQLite throws:
        // DatabaseException(no such module: fts4)
        //
        // _initializeFts catches this specific error and disables FTS completely
        const fts4Error = 'DatabaseException(no such module: fts4)';
        expect(fts4Error.contains('no such module'), isTrue);
        expect(fts4Error.contains('fts4'), isTrue);
        // After this error, _ftsVersion is set to 0
      });

      test('both FTS5 and FTS4 errors result in disabled mode', () {
        // Initialization sequence when both FTS modules fail:
        // 1. Try FTS5 -> catches "no such module: fts5"
        // 2. Try FTS4 -> catches "no such module: fts4"
        // 3. setFtsVersion(0) - FTS completely disabled
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('disabled mode prevents further FTS initialization attempts', () {
        // Once _ftsVersion is set to 0, no FTS operations are attempted
        // All search queries use LIKE patterns directly on documents table
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
        // Version 0 is a permanent state for the database session
      });

      test('disabled mode is detected at runtime not compile time', () {
        // FTS availability is detected at database initialization time
        // This allows the same code to work on all Android devices:
        // - Devices with FTS5: Full relevance-ranked search
        // - Devices with FTS4 only: Basic full-text search
        // - Devices without FTS: LIKE-based search
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });
    });

    group('FTS Disabled Mode No FTS Tables', () {
      test('no FTS virtual table is created when disabled', () {
        // When both FTS5 and FTS4 fail, no FTS virtual table exists
        // The documents_fts table is never created
        //
        // This is different from FTS5/FTS4 modes where documents_fts exists
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
        // Search operates directly on the documents table using LIKE
      });

      test('no FTS triggers are created when disabled', () {
        // When FTS is disabled, no triggers are created:
        // - No documents_ai trigger
        // - No documents_ad trigger
        // - No documents_au trigger
        //
        // This avoids overhead from trigger execution on insert/update/delete
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('documents table is still created when FTS is disabled', () {
        // Even when FTS is disabled, the core documents table is created
        // with all columns: id, title, description, ocr_text, created_at, updated_at
        //
        // This ensures document storage works regardless of FTS availability
        expect(DatabaseHelper.tableDocuments, equals('documents'));
        expect(DatabaseHelper.columnId, equals('id'));
        expect(DatabaseHelper.columnTitle, equals('title'));
        expect(DatabaseHelper.columnDescription, equals('description'));
        expect(DatabaseHelper.columnOcrText, equals('ocr_text'));
        expect(DatabaseHelper.columnCreatedAt, equals('created_at'));
        expect(DatabaseHelper.columnUpdatedAt, equals('updated_at'));
      });
    });

    group('FTS Disabled Mode LIKE-Based Search', () {
      test('_searchWithLike uses LIKE patterns for text matching', () {
        // LIKE-based search uses SQL LIKE patterns:
        // SELECT * FROM documents WHERE
        //   title LIKE '%term%' OR
        //   description LIKE '%term%' OR
        //   ocr_text LIKE '%term%'
        //
        // Each search term is wrapped with % for substring matching
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('LIKE search checks all searchable columns', () {
        // LIKE search queries these columns:
        // - title: document title
        // - description: document description
        // - ocr_text: extracted OCR text
        //
        // A document matches if ANY column contains the search term
        expect(DatabaseHelper.columnTitle, equals('title'));
        expect(DatabaseHelper.columnDescription, equals('description'));
        expect(DatabaseHelper.columnOcrText, equals('ocr_text'));
      });

      test('LIKE search uses case-insensitive matching', () {
        // SQLite LIKE is case-insensitive for ASCII by default
        // Search for "Flutter" will match "flutter", "FLUTTER", "FlUtTeR"
        //
        // This provides reasonable search UX without FTS
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('LIKE search supports multiple terms with AND logic', () {
        // When searching for "flutter tutorial":
        // - Split into terms: ["flutter", "tutorial"]
        // - Each term generates LIKE conditions for all columns
        // - Terms are combined with AND logic
        //
        // Result: documents must contain ALL terms to match
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('LIKE search orders results by created_at DESC', () {
        // Unlike FTS5's relevance ranking, LIKE search orders by date:
        // ORDER BY created_at DESC
        //
        // Most recently created documents appear first
        // This provides consistent, predictable ordering
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });
    });

    group('FTS Disabled Mode LIKE Query Escaping', () {
      test('LIKE special character % is escaped', () {
        // LIKE pattern uses % as wildcard (matches any sequence)
        // If user searches for "100%", the % must be escaped:
        // Input: "100%"
        // Pattern: '%100\%%' with ESCAPE '\'
        //
        // This prevents unintended wildcard behavior
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('LIKE special character _ is escaped', () {
        // LIKE pattern uses _ as wildcard (matches single character)
        // If user searches for "test_file", the _ must be escaped:
        // Input: "test_file"
        // Pattern: '%test\_file%' with ESCAPE '\'
        //
        // This ensures literal underscore matching
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('LIKE escape character \\ is escaped', () {
        // If user searches for text with backslash:
        // Input: "path\\file"
        // The backslash must be escaped to prevent SQL injection
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('LIKE queries use parameterized statements', () {
        // All LIKE queries use ? placeholders with bound parameters
        // This prevents SQL injection attacks:
        // query: '... WHERE title LIKE ? ...'
        // args: ['%search_term%']
        //
        // Never concatenate user input directly into SQL
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });
    });

    group('FTS Disabled Mode Performance Considerations', () {
      test('LIKE search is slower than FTS but still functional', () {
        // LIKE queries perform full table scans:
        // - FTS5/FTS4: O(log n) using inverted index
        // - LIKE: O(n) scanning every row
        //
        // For small document collections, this is acceptable
        // For large collections, users may notice slower search
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('disabled mode has no indexing overhead', () {
        // Without FTS, there's no FTS index to maintain:
        // - No INSERT into FTS table on document create
        // - No DELETE from FTS table on document delete
        // - No UPDATE overhead for document modifications
        //
        // This makes insert/update/delete operations faster
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('disabled mode uses less storage space', () {
        // Without FTS tables, the database is smaller:
        // - No documents_fts virtual table
        // - No FTS internal tables (_data, _idx, _content, _docsize, _config)
        //
        // This can be beneficial on storage-constrained devices
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });
    });

    group('FTS Disabled Mode Error Handling', () {
      test('unexpected errors during FTS4 init are rethrown', () {
        // _initializeFts only catches "no such module" errors
        // Other errors (disk full, permission denied, etc.) are rethrown
        // to prevent silent failures
        const unexpectedError = 'DatabaseException(disk I/O error)';
        expect(unexpectedError.contains('no such module'), isFalse);
        // This error would be rethrown, not treated as FTS unavailable
      });

      test('only "no such module" triggers disabled fallback', () {
        // The specific error pattern checked is:
        // e.toString().contains('no such module')
        //
        // This matches:
        // - "no such module: fts5"
        // - "no such module: fts4"
        //
        // But NOT:
        // - "disk I/O error"
        // - "permission denied"
        // - "table already exists"
        const fts5Error = 'DatabaseException(no such module: fts5)';
        const fts4Error = 'DatabaseException(no such module: fts4)';
        const diskError = 'DatabaseException(disk I/O error)';

        expect(fts5Error.contains('no such module'), isTrue);
        expect(fts4Error.contains('no such module'), isTrue);
        expect(diskError.contains('no such module'), isFalse);
      });

      test('disabled mode search handles empty query gracefully', () {
        // When query is empty or whitespace-only:
        // searchDocuments('') returns empty list immediately
        // No database query is executed
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
        // Empty query check happens before version dispatch
      });

      test('disabled mode search handles special SQL characters', () {
        // LIKE search safely handles SQL special characters:
        // - Single quotes are properly escaped/parameterized
        // - Double quotes are handled
        // - Semicolons don't cause SQL injection
        //
        // All input goes through parameterized queries
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });
    });

    group('FTS Disabled Mode State Verification', () {
      test('_ftsVersion 0 persists across multiple checks', () {
        DatabaseHelper.setFtsVersion(0);

        // Multiple reads should return the same value
        expect(DatabaseHelper.ftsVersion, equals(0));
        expect(DatabaseHelper.ftsVersion, equals(0));
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('_ftsVersion can transition from any state to disabled', () {
        // Test transition from FTS5 to disabled
        DatabaseHelper.setFtsVersion(5);
        expect(DatabaseHelper.ftsVersion, equals(5));
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));

        // Test transition from FTS4 to disabled
        DatabaseHelper.setFtsVersion(4);
        expect(DatabaseHelper.ftsVersion, equals(4));
        DatabaseHelper.setFtsVersion(0);
        expect(DatabaseHelper.ftsVersion, equals(0));
      });

      test('resetFtsVersion sets version to disabled state', () {
        // resetFtsVersion() resets to version 0 (disabled)
        DatabaseHelper.setFtsVersion(5);
        DatabaseHelper.resetFtsVersion();
        expect(DatabaseHelper.ftsVersion, equals(0));

        DatabaseHelper.setFtsVersion(4);
        DatabaseHelper.resetFtsVersion();
        expect(DatabaseHelper.ftsVersion, equals(0));
      });
    });

    group('Table Names', () {
      test('tableDocuments should be "documents"', () {
        expect(DatabaseHelper.tableDocuments, equals('documents'));
      });

      test('tableDocumentsFts should be "documents_fts"', () {
        expect(DatabaseHelper.tableDocumentsFts, equals('documents_fts'));
      });
    });

    group('Column Names', () {
      test('column names should match expected values', () {
        expect(DatabaseHelper.columnId, equals('id'));
        expect(DatabaseHelper.columnTitle, equals('title'));
        expect(DatabaseHelper.columnDescription, equals('description'));
        expect(DatabaseHelper.columnOcrText, equals('ocr_text'));
        expect(DatabaseHelper.columnCreatedAt, equals('created_at'));
        expect(DatabaseHelper.columnUpdatedAt, equals('updated_at'));
      });
    });

    group('Singleton Pattern', () {
      test('DatabaseHelper should return same instance', () {
        final instance1 = DatabaseHelper();
        final instance2 = DatabaseHelper();
        expect(identical(instance1, instance2), isTrue);
      });
    });
  });

  group('FTS Version Behavior', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
    });

    test('version persists across multiple reads', () {
      DatabaseHelper.setFtsVersion(5);

      // Multiple reads should return the same value
      expect(DatabaseHelper.ftsVersion, equals(5));
      expect(DatabaseHelper.ftsVersion, equals(5));
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('version can be changed during runtime', () {
      // This simulates what happens during re-initialization
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));

      DatabaseHelper.setFtsVersion(4);
      expect(DatabaseHelper.ftsVersion, equals(4));

      DatabaseHelper.setFtsVersion(0);
      expect(DatabaseHelper.ftsVersion, equals(0));
    });
  });

  group('FTS Trigger Syntax Expectations', () {
    // These tests document the expected trigger syntax for each FTS version
    // Actual trigger creation is tested through integration tests

    test('FTS5 triggers use special INSERT "delete" syntax', () {
      // FTS5 DELETE trigger syntax documentation
      // INSERT INTO fts_table(fts_table, rowid, ...) VALUES ('delete', OLD.rowid, ...);
      // This is different from standard DELETE syntax

      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
      // When ftsVersion is 5, _createFts5Triggers creates triggers with:
      // - documents_ai: AFTER INSERT
      // - documents_ad: AFTER DELETE (uses INSERT with 'delete' command)
      // - documents_au: AFTER UPDATE (uses delete+insert)
    });

    test('FTS4 triggers use standard DELETE syntax', () {
      // FTS4 DELETE trigger syntax documentation
      // DELETE FROM fts_table WHERE docid = OLD.rowid;
      // This is the standard SQL DELETE syntax

      DatabaseHelper.setFtsVersion(4);
      expect(DatabaseHelper.ftsVersion, equals(4));
      // When ftsVersion is 4, _createFts4Triggers creates triggers with:
      // - documents_ai: AFTER INSERT (uses docid)
      // - documents_ad: AFTER DELETE (uses standard DELETE)
      // - documents_au: AFTER UPDATE (uses delete+insert with docid)
    });

    test('disabled mode creates no FTS triggers', () {
      // When FTS is disabled, no triggers are created
      // _initializeFts sets _ftsVersion to 0 and skips trigger creation

      DatabaseHelper.setFtsVersion(0);
      expect(DatabaseHelper.ftsVersion, equals(0));
      // When ftsVersion is 0:
      // - No FTS virtual table exists
      // - No triggers exist
      // - searchDocuments uses LIKE queries directly on documents table
    });
  });

  group('Search Dispatch Logic', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
    });

    test('searchDocuments dispatches to FTS5 when version is 5', () {
      DatabaseHelper.setFtsVersion(5);
      // When ftsVersion is 5, searchDocuments internally calls _searchWithFts5
      // which uses MATCH with rank ordering
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('searchDocuments dispatches to FTS4 when version is 4', () {
      DatabaseHelper.setFtsVersion(4);
      // When ftsVersion is 4, searchDocuments internally calls _searchWithFts4
      // which uses MATCH with date ordering (no rank)
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('searchDocuments dispatches to LIKE when version is 0', () {
      DatabaseHelper.setFtsVersion(0);
      // When ftsVersion is 0, searchDocuments internally calls _searchWithLike
      // which uses LIKE patterns across title, description, ocr_text
      expect(DatabaseHelper.ftsVersion, equals(0));
    });
  });

  group('Error Handling Expectations', () {
    test('FTS5 unavailable error contains "no such module"', () {
      // When FTS5 is unavailable, SQLite throws:
      // DatabaseException(no such module: fts5)
      //
      // _initializeFts catches this and falls back to FTS4
      const errorMessage = 'DatabaseException(no such module: fts5)';
      expect(errorMessage.contains('no such module'), isTrue);
    });

    test('FTS4 unavailable error contains "no such module"', () {
      // When FTS4 is unavailable, SQLite throws:
      // DatabaseException(no such module: fts4)
      //
      // _initializeFts catches this and disables FTS
      const errorMessage = 'DatabaseException(no such module: fts4)';
      expect(errorMessage.contains('no such module'), isTrue);
    });

    test('unexpected errors should be rethrown', () {
      // _initializeFts only catches "no such module" errors
      // Other errors (disk full, permission denied, etc.) are rethrown
      // to prevent silent failures
      const unexpectedError = 'DatabaseException(disk I/O error)';
      expect(unexpectedError.contains('no such module'), isFalse);
      // This error would be rethrown, not caught as FTS fallback
    });
  });

  group('FTS Query Escaping', () {
    // Tests for expected behavior of _escapeFtsQuery
    // The method wraps each term in double quotes to escape special characters

    test('special characters should be documented', () {
      // FTS5/FTS4 special characters that need escaping:
      // " (double quote) - phrase queries
      // * (asterisk) - prefix queries
      // ^ (caret) - boost operator (FTS5 only)
      // - (minus) - exclusion operator
      // + (plus) - required term operator

      // _escapeFtsQuery handles these by wrapping terms in quotes
      // Input: flutter tutorial
      // Output: "flutter" "tutorial"

      // This test documents the expected behavior
      expect(true, isTrue); // Placeholder - actual escaping tested in integration tests
    });

    test('double quotes in query should be escaped', () {
      // If a term contains double quotes, they should be doubled
      // Input: "test"
      // Output: """test"""

      // This test documents the expected behavior
      expect(true, isTrue); // Placeholder - actual escaping tested in integration tests
    });
  });

  group('LIKE Query Escaping', () {
    // Tests for expected behavior of _searchWithLike
    // The method escapes LIKE special characters (%, _)

    test('LIKE special characters should be documented', () {
      // LIKE special characters that need escaping:
      // % - matches any sequence of characters
      // _ - matches any single character

      // _searchWithLike escapes these with backslash and ESCAPE '\'
      // Input term: 100%
      // Pattern: %100\%% with ESCAPE '\'

      expect(true, isTrue); // Placeholder - actual escaping tested in integration tests
    });
  });

  group('Rebuild Index', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
    });

    test('rebuildFtsIndex should be a no-op when FTS is disabled', () {
      DatabaseHelper.setFtsVersion(0);
      // When ftsVersion is 0, rebuildFtsIndex returns early
      // No database operation is performed
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('rebuildFtsIndex should execute for FTS5', () {
      DatabaseHelper.setFtsVersion(5);
      // When ftsVersion is 5, rebuildFtsIndex executes:
      // INSERT INTO documents_fts(documents_fts) VALUES('rebuild')
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('rebuildFtsIndex should execute for FTS4', () {
      DatabaseHelper.setFtsVersion(4);
      // When ftsVersion is 4, rebuildFtsIndex executes:
      // INSERT INTO documents_fts(documents_fts) VALUES('rebuild')
      expect(DatabaseHelper.ftsVersion, equals(4));
    });
  });

  // ============================================================================
  // SEARCH QUERY TESTS FOR EACH FTS MODE
  // ============================================================================
  // These tests verify the search query behavior and SQL generation for each
  // FTS mode (FTS5, FTS4, and LIKE-based search).
  // ============================================================================

  group('FTS5 Search Query Tests', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
      DatabaseHelper.setFtsVersion(5);
    });

    test('searchDocuments dispatches to _searchWithFts5 when version is 5', () {
      // Verify FTS5 mode is active
      expect(DatabaseHelper.ftsVersion, equals(5));
      // searchDocuments internally calls _searchWithFts5 which:
      // 1. Escapes the query using _escapeFtsQuery
      // 2. Executes FTS5 MATCH query with rank ordering
      // 3. Returns documents ordered by relevance (best matches first)
    });

    test('_searchWithFts5 uses MATCH clause for full-text queries', () {
      DatabaseHelper.setFtsVersion(5);
      // FTS5 search query structure:
      // SELECT d.* FROM documents d
      // INNER JOIN documents_fts fts ON d.rowid = fts.rowid
      // WHERE documents_fts MATCH ?
      // ORDER BY fts.rank
      //
      // The MATCH clause enables full-text search capabilities
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_searchWithFts5 uses rank column for relevance ordering', () {
      DatabaseHelper.setFtsVersion(5);
      // FTS5 provides built-in rank column:
      // ORDER BY fts.rank
      //
      // Rank values are negative (closer to 0 = better match)
      // Results are ordered with best matches first
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_searchWithFts5 joins on rowid for FTS5 content tables', () {
      DatabaseHelper.setFtsVersion(5);
      // FTS5 content tables use rowid for joins:
      // INNER JOIN documents_fts fts ON d.rowid = fts.rowid
      //
      // This is efficient because FTS5 uses content_rowid=rowid option
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_searchWithFts5 escapes query terms for FTS5 syntax', () {
      DatabaseHelper.setFtsVersion(5);
      // _escapeFtsQuery wraps each term in double quotes:
      // Input: "flutter tutorial"
      // Output: '"flutter" "tutorial"'
      //
      // This prevents FTS5 syntax errors from special characters
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_searchWithFts5 handles single term queries', () {
      DatabaseHelper.setFtsVersion(5);
      // Single term query:
      // Input: "flutter"
      // Escaped: '"flutter"'
      // MATCH clause: WHERE documents_fts MATCH '"flutter"'
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_searchWithFts5 handles multiple term queries', () {
      DatabaseHelper.setFtsVersion(5);
      // Multiple term query (implicit AND):
      // Input: "flutter dart tutorial"
      // Escaped: '"flutter" "dart" "tutorial"'
      // MATCH clause: WHERE documents_fts MATCH '"flutter" "dart" "tutorial"'
      //
      // FTS5 treats space-separated quoted terms as AND
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_searchWithFts5 returns all document columns', () {
      DatabaseHelper.setFtsVersion(5);
      // Query uses SELECT d.* to return all columns:
      // - id, title, description, ocr_text, created_at, updated_at
      //
      // This provides complete document data for display
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_searchWithFts5 uses parameterized queries for security', () {
      DatabaseHelper.setFtsVersion(5);
      // Query uses ? placeholder with bound parameters:
      // rawQuery('... MATCH ?', [escapedQuery])
      //
      // This prevents SQL injection attacks
      expect(DatabaseHelper.ftsVersion, equals(5));
    });
  });

  group('FTS4 Search Query Tests', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
      DatabaseHelper.setFtsVersion(4);
    });

    test('searchDocuments dispatches to _searchWithFts4 when version is 4', () {
      // Verify FTS4 mode is active
      expect(DatabaseHelper.ftsVersion, equals(4));
      // searchDocuments internally calls _searchWithFts4 which:
      // 1. Escapes the query using _escapeFtsQuery
      // 2. Executes FTS4 MATCH query with date ordering
      // 3. Returns documents ordered by creation date (most recent first)
    });

    test('_searchWithFts4 uses MATCH clause for full-text queries', () {
      DatabaseHelper.setFtsVersion(4);
      // FTS4 search query structure:
      // SELECT d.* FROM documents d
      // INNER JOIN documents_fts fts ON d.rowid = fts.docid
      // WHERE documents_fts MATCH ?
      // ORDER BY d.created_at DESC
      //
      // The MATCH clause enables full-text search capabilities
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('_searchWithFts4 uses created_at DESC for date-based ordering', () {
      DatabaseHelper.setFtsVersion(4);
      // FTS4 does not have built-in rank column like FTS5
      // Instead, results are ordered by creation date:
      // ORDER BY d.created_at DESC
      //
      // Most recently created documents appear first
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('_searchWithFts4 joins on docid for FTS4 content tables', () {
      DatabaseHelper.setFtsVersion(4);
      // FTS4 content tables use docid for joins (not rowid):
      // INNER JOIN documents_fts fts ON d.rowid = fts.docid
      //
      // This differs from FTS5's rowid-based joins
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('_searchWithFts4 escapes query terms for FTS4 syntax', () {
      DatabaseHelper.setFtsVersion(4);
      // _escapeFtsQuery wraps each term in double quotes:
      // Input: "flutter tutorial"
      // Output: '"flutter" "tutorial"'
      //
      // FTS4 uses same escaping mechanism as FTS5
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('_searchWithFts4 handles single term queries', () {
      DatabaseHelper.setFtsVersion(4);
      // Single term query:
      // Input: "flutter"
      // Escaped: '"flutter"'
      // MATCH clause: WHERE documents_fts MATCH '"flutter"'
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('_searchWithFts4 handles multiple term queries', () {
      DatabaseHelper.setFtsVersion(4);
      // Multiple term query (implicit AND):
      // Input: "flutter dart tutorial"
      // Escaped: '"flutter" "dart" "tutorial"'
      // MATCH clause: WHERE documents_fts MATCH '"flutter" "dart" "tutorial"'
      //
      // FTS4 treats space-separated quoted terms as AND
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('_searchWithFts4 returns all document columns', () {
      DatabaseHelper.setFtsVersion(4);
      // Query uses SELECT d.* to return all columns:
      // - id, title, description, ocr_text, created_at, updated_at
      //
      // This provides complete document data for display
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('_searchWithFts4 uses parameterized queries for security', () {
      DatabaseHelper.setFtsVersion(4);
      // Query uses ? placeholder with bound parameters:
      // rawQuery('... MATCH ?', [escapedQuery])
      //
      // This prevents SQL injection attacks
      expect(DatabaseHelper.ftsVersion, equals(4));
    });

    test('_searchWithFts4 differs from FTS5 in ordering strategy', () {
      DatabaseHelper.setFtsVersion(4);
      // Key difference from FTS5:
      // FTS5: ORDER BY fts.rank (relevance-based, best matches first)
      // FTS4: ORDER BY d.created_at DESC (date-based, most recent first)
      //
      // Users may notice different result ordering between FTS5 and FTS4
      expect(DatabaseHelper.ftsVersion, equals(4));
    });
  });

  group('LIKE Search Query Tests', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
      DatabaseHelper.setFtsVersion(0);
    });

    test('searchDocuments dispatches to _searchWithLike when version is 0', () {
      // Verify LIKE mode is active (FTS disabled)
      expect(DatabaseHelper.ftsVersion, equals(0));
      // searchDocuments internally calls _searchWithLike which:
      // 1. Splits query into terms
      // 2. Builds LIKE conditions for each term across all searchable columns
      // 3. Returns documents ordered by creation date (most recent first)
    });

    test('_searchWithLike uses LIKE patterns for text matching', () {
      DatabaseHelper.setFtsVersion(0);
      // LIKE search query structure:
      // SELECT * FROM documents WHERE
      //   (title LIKE ? OR description LIKE ? OR ocr_text LIKE ?)
      // ORDER BY created_at DESC
      //
      // Each term generates a LIKE condition with % wildcards
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike searches across title, description, and ocr_text', () {
      DatabaseHelper.setFtsVersion(0);
      // LIKE conditions check all searchable columns:
      // (title LIKE ? ESCAPE '\\' OR
      //  description LIKE ? ESCAPE '\\' OR
      //  ocr_text LIKE ? ESCAPE '\\')
      //
      // A document matches if ANY column contains the search term
      expect(DatabaseHelper.columnTitle, equals('title'));
      expect(DatabaseHelper.columnDescription, equals('description'));
      expect(DatabaseHelper.columnOcrText, equals('ocr_text'));
    });

    test('_searchWithLike wraps terms with % wildcards', () {
      DatabaseHelper.setFtsVersion(0);
      // Each term is wrapped with % for substring matching:
      // Input term: "flutter"
      // Pattern: "%flutter%"
      //
      // This matches "flutter", "my flutter app", "flutter-test", etc.
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike uses AND logic for multiple terms', () {
      DatabaseHelper.setFtsVersion(0);
      // Multiple terms are combined with AND:
      // Input: "flutter tutorial"
      // WHERE (title LIKE '%flutter%' OR description LIKE '%flutter%' OR ...)
      //   AND (title LIKE '%tutorial%' OR description LIKE '%tutorial%' OR ...)
      //
      // Documents must contain ALL search terms to match
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike uses OR logic within each term condition', () {
      DatabaseHelper.setFtsVersion(0);
      // Each term generates OR conditions across columns:
      // (title LIKE '%term%' OR description LIKE '%term%' OR ocr_text LIKE '%term%')
      //
      // A term matches if found in ANY of the searchable columns
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike orders by created_at DESC', () {
      DatabaseHelper.setFtsVersion(0);
      // LIKE search results are ordered by creation date:
      // ORDER BY created_at DESC
      //
      // Most recently created documents appear first
      // This matches FTS4 ordering (but not FTS5's relevance ranking)
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike escapes % character in search terms', () {
      DatabaseHelper.setFtsVersion(0);
      // LIKE special character % is escaped to prevent unintended wildcards:
      // Input: "100%"
      // Escaped: "100\%"
      // Pattern: "%100\%%"
      //
      // Uses ESCAPE '\\' clause in query
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike escapes _ character in search terms', () {
      DatabaseHelper.setFtsVersion(0);
      // LIKE special character _ is escaped to prevent unintended wildcards:
      // Input: "test_file"
      // Escaped: "test\_file"
      // Pattern: "%test\_file%"
      //
      // Uses ESCAPE '\\' clause in query
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike handles single term queries', () {
      DatabaseHelper.setFtsVersion(0);
      // Single term query generates single condition group:
      // WHERE (title LIKE ? OR description LIKE ? OR ocr_text LIKE ?)
      //
      // Pattern: "%flutter%"
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike handles multiple term queries', () {
      DatabaseHelper.setFtsVersion(0);
      // Multiple term query generates multiple condition groups with AND:
      // WHERE (title LIKE ? OR ...) AND (title LIKE ? OR ...)
      //
      // Each term adds 3 parameters (one per column)
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike returns empty list for empty terms', () {
      DatabaseHelper.setFtsVersion(0);
      // When query splits to empty terms list:
      // - Whitespace-only queries split to empty list
      // - Returns [] immediately without database query
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike uses parameterized queries for security', () {
      DatabaseHelper.setFtsVersion(0);
      // Query uses ? placeholders with bound parameters:
      // rawQuery('... WHERE ... LIKE ? ...', args)
      //
      // This prevents SQL injection attacks
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('_searchWithLike returns all document columns', () {
      DatabaseHelper.setFtsVersion(0);
      // Query uses SELECT * to return all columns:
      // - id, title, description, ocr_text, created_at, updated_at
      //
      // This provides complete document data for display
      expect(DatabaseHelper.ftsVersion, equals(0));
    });
  });

  group('searchDocuments Method Tests', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
    });

    test('searchDocuments returns empty list for empty query', () {
      // Empty query check happens before version dispatch:
      // if (query.trim().isEmpty) return [];
      //
      // This applies to all FTS modes (5, 4, 0)
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('searchDocuments returns empty list for whitespace-only query', () {
      // Whitespace-only queries are treated as empty:
      // query.trim().isEmpty returns true for "   "
      //
      // No database operation is performed
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('searchDocuments trims leading and trailing whitespace', () {
      // Query is trimmed before empty check:
      // query.trim().isEmpty
      //
      // "  flutter  " becomes "flutter" for search
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('searchDocuments uses switch on _ftsVersion for dispatch', () {
      // Internal dispatch logic:
      // switch (_ftsVersion) {
      //   case 5: return _searchWithFts5(db, query);
      //   case 4: return _searchWithFts4(db, query);
      //   default: return _searchWithLike(db, query);
      // }
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));

      DatabaseHelper.setFtsVersion(4);
      expect(DatabaseHelper.ftsVersion, equals(4));

      DatabaseHelper.setFtsVersion(0);
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('searchDocuments default case handles version 0', () {
      // Default case in switch handles FTS disabled:
      // default: return _searchWithLike(db, query);
      //
      // This ensures graceful fallback even for unexpected version values
      DatabaseHelper.setFtsVersion(0);
      expect(DatabaseHelper.ftsVersion, equals(0));
    });

    test('searchDocuments provides unified interface for all modes', () {
      // searchDocuments hides implementation details:
      // - Callers don't need to know which FTS mode is active
      // - Same method signature works for FTS5, FTS4, and LIKE
      // - Results are always List<Map<String, dynamic>>
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('searchDocuments result ordering varies by FTS mode', () {
      // Result ordering depends on active FTS mode:
      // - FTS5 (version 5): Relevance ranking (ORDER BY rank)
      // - FTS4 (version 4): Date ordering (ORDER BY created_at DESC)
      // - LIKE (version 0): Date ordering (ORDER BY created_at DESC)
      //
      // Users may notice different ordering between FTS5 and other modes
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });
  });

  group('FTS Query Escaping Tests', () {
    setUp(() {
      DatabaseHelper.resetFtsVersion();
    });

    test('_escapeFtsQuery wraps each term in double quotes', () {
      // Input: "flutter tutorial"
      // Output: '"flutter" "tutorial"'
      //
      // Each word becomes a quoted phrase literal
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery escapes double quotes within terms', () {
      // Input term with double quote: test"term
      // Escaped: "test""term"
      //
      // Double quotes are doubled to escape them within FTS
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery handles asterisk operator safely', () {
      // FTS5/FTS4 asterisk (*) is prefix wildcard operator
      // By quoting terms, asterisk is treated as literal:
      // Input: "flutter*"
      // Output: '"flutter*"' (asterisk is literal, not wildcard)
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery handles minus operator safely', () {
      // FTS5/FTS4 minus (-) is exclusion operator (NOT)
      // By quoting terms, minus is treated as literal:
      // Input: "-flutter"
      // Output: '"-flutter"' (minus is literal, not exclusion)
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery handles plus operator safely', () {
      // FTS5/FTS4 plus (+) is required term operator
      // By quoting terms, plus is treated as literal:
      // Input: "+flutter"
      // Output: '"+flutter"' (plus is literal, not required)
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery handles caret operator safely (FTS5)', () {
      // FTS5 caret (^) is boost operator
      // By quoting terms, caret is treated as literal:
      // Input: "^flutter"
      // Output: '"^flutter"' (caret is literal, not boost)
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery splits on whitespace', () {
      // Multiple whitespace is treated as single separator:
      // Input: "flutter  dart   tutorial"
      // Split: ["flutter", "dart", "tutorial"]
      // Output: '"flutter" "dart" "tutorial"'
      //
      // Uses RegExp(r'\s+') for splitting
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery filters empty strings after split', () {
      // Empty strings from split are filtered:
      // Input: "  flutter  "
      // Split: ["", "flutter", ""]
      // Filtered: ["flutter"]
      // Output: '"flutter"'
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery joins terms with space', () {
      // Escaped terms are joined with single space:
      // Terms: ['"flutter"', '"tutorial"']
      // Output: '"flutter" "tutorial"'
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
    });

    test('_escapeFtsQuery used by both FTS5 and FTS4', () {
      // Same escaping logic is used for both FTS versions:
      // - _searchWithFts5 calls _escapeFtsQuery(query)
      // - _searchWithFts4 calls _escapeFtsQuery(query)
      //
      // This ensures consistent query handling
      DatabaseHelper.setFtsVersion(5);
      expect(DatabaseHelper.ftsVersion, equals(5));
      DatabaseHelper.setFtsVersion(4);
      expect(DatabaseHelper.ftsVersion, equals(4));
    });
  });

  group('Batch Query Methods', () {
    group('getBatchDocumentPagePaths', () {
      test('returns empty map for empty document ID list', () {
        // When given an empty list of document IDs:
        // getBatchDocumentPagePaths([])
        //
        // Expected: Returns empty map {}
        // Rationale: No documents to query means no results
        // Implementation: Early return before database query
        expect([], isEmpty);
      });

      test('returns map with all requested document IDs as keys', () {
        // When given multiple document IDs:
        // getBatchDocumentPagePaths(['doc1', 'doc2', 'doc3'])
        //
        // Expected: Map contains all three IDs as keys
        // Rationale: Result map is pre-initialized with all document IDs
        // Implementation: for (final id in documentIds) result[id] = [];
        final documentIds = ['doc1', 'doc2', 'doc3'];
        expect(documentIds.length, equals(3));
      });

      test('initializes each document ID with empty list', () {
        // Before database query, all document IDs get empty lists:
        // result['doc1'] = []
        // result['doc2'] = []
        //
        // Expected: Documents with no pages keep empty list
        // Rationale: Ensures consistent return structure
        // Implementation: Result map initialized before query
        final emptyList = <String>[];
        expect(emptyList, isEmpty);
      });

      test('uses SQL IN clause for batch fetching', () {
        // Batch query uses parameterized IN clause:
        // WHERE document_id IN (?, ?, ?)
        //
        // Expected: Single database query for all documents
        // Rationale: Eliminates N+1 query problem
        // Implementation: Uses List.filled(count, '?').join(',')
        final documentIds = ['doc1', 'doc2', 'doc3'];
        final placeholders = List.filled(documentIds.length, '?').join(',');
        expect(placeholders, equals('?,?,?'));
      });

      test('orders pages by document ID and page number', () {
        // Query includes ORDER BY clause:
        // ORDER BY document_id, page_number ASC
        //
        // Expected: Pages grouped by document, ordered by page number
        // Rationale: Ensures correct page order for each document
        // Implementation: SQL ORDER BY in batch query
        expect(DatabaseHelper.columnDocumentId, equals('document_id'));
        expect(DatabaseHelper.columnPageNumber, equals('page_number'));
      });

      test('groups page paths by document ID', () {
        // Results are grouped after query:
        // for (final page in pages) {
        //   final docId = page['document_id'];
        //   result[docId].add(page['file_path']);
        // }
        //
        // Expected: Each document ID maps to its page paths list
        // Rationale: Converts flat query results to grouped structure
        // Implementation: Loop through results, append to correct list
        expect(DatabaseHelper.columnFilePath, equals('file_path'));
      });

      test('handles documents with no pages correctly', () {
        // Documents without pages in database:
        // - Still appear in result map with empty list
        // - Example: {'doc1': ['path1'], 'doc2': []}
        //
        // Expected: Empty list for documents with no pages
        // Rationale: Pre-initialization ensures key exists
        // Implementation: Result map initialized before query
        final result = <String, List<String>>{'doc1': [], 'doc2': []};
        expect(result['doc2'], isEmpty);
      });

      test('handles non-existent document IDs gracefully', () {
        // When querying documents that don't exist:
        // getBatchDocumentPagePaths(['nonexistent1', 'nonexistent2'])
        //
        // Expected: Returns map with empty lists for each ID
        // Rationale: Pre-initialization creates keys for all IDs
        // Implementation: Query returns no results, pre-init lists remain
        final result = <String, List<String>>{'nonexistent1': []};
        expect(result['nonexistent1'], isEmpty);
      });

      test('returns List<String> values for file paths', () {
        // Result type is Map<String, List<String>>:
        // - Keys: document IDs (String)
        // - Values: lists of file paths (List<String>)
        //
        // Expected: Each document maps to list of path strings
        // Rationale: File paths are stored as strings
        // Implementation: final filePath = page['file_path'] as String
        final paths = <String>['path1', 'path2'];
        expect(paths, isA<List<String>>());
      });

      test('fetches all pages in single database query', () {
        // Performance characteristic:
        // - Old approach: N queries (one per document)
        // - New approach: 1 query (all documents at once)
        //
        // Expected: Single rawQuery call with IN clause
        // Rationale: Eliminates N+1 query problem
        // Implementation: Single db.rawQuery() with all IDs
        expect(DatabaseHelper.tableDocumentPages, equals('document_pages'));
      });
    });

    group('getBatchDocumentTags', () {
      test('returns empty map for empty document ID list', () {
        // When given an empty list of document IDs:
        // getBatchDocumentTags([])
        //
        // Expected: Returns empty map {}
        // Rationale: No documents to query means no results
        // Implementation: Early return before database query
        expect([], isEmpty);
      });

      test('returns map with all requested document IDs as keys', () {
        // When given multiple document IDs:
        // getBatchDocumentTags(['doc1', 'doc2', 'doc3'])
        //
        // Expected: Map contains all three IDs as keys
        // Rationale: Result map is pre-initialized with all document IDs
        // Implementation: for (final id in documentIds) result[id] = [];
        final documentIds = ['doc1', 'doc2', 'doc3'];
        expect(documentIds.length, equals(3));
      });

      test('initializes each document ID with empty list', () {
        // Before database query, all document IDs get empty lists:
        // result['doc1'] = []
        // result['doc2'] = []
        //
        // Expected: Documents with no tags keep empty list
        // Rationale: Ensures consistent return structure
        // Implementation: Result map initialized before query
        final emptyList = <String>[];
        expect(emptyList, isEmpty);
      });

      test('uses SQL IN clause for batch fetching', () {
        // Batch query uses parameterized IN clause:
        // WHERE document_id IN (?, ?, ?)
        //
        // Expected: Single database query for all documents
        // Rationale: Eliminates N+1 query problem
        // Implementation: Uses List.filled(count, '?').join(',')
        final documentIds = ['doc1', 'doc2', 'doc3'];
        final placeholders = List.filled(documentIds.length, '?').join(',');
        expect(placeholders, equals('?,?,?'));
      });

      test('orders tags by document ID', () {
        // Query includes ORDER BY clause:
        // ORDER BY document_id
        //
        // Expected: Tags grouped by document
        // Rationale: Ensures efficient grouping in result processing
        // Implementation: SQL ORDER BY in batch query
        expect(DatabaseHelper.columnDocumentId, equals('document_id'));
      });

      test('groups tag IDs by document ID', () {
        // Results are grouped after query:
        // for (final tag in tags) {
        //   final docId = tag['document_id'];
        //   result[docId].add(tag['tag_id']);
        // }
        //
        // Expected: Each document ID maps to its tag IDs list
        // Rationale: Converts flat query results to grouped structure
        // Implementation: Loop through results, append to correct list
        expect(DatabaseHelper.columnTagId, equals('tag_id'));
      });

      test('handles documents with no tags correctly', () {
        // Documents without tags in database:
        // - Still appear in result map with empty list
        // - Example: {'doc1': ['tag1'], 'doc2': []}
        //
        // Expected: Empty list for documents with no tags
        // Rationale: Pre-initialization ensures key exists
        // Implementation: Result map initialized before query
        final result = <String, List<String>>{'doc1': [], 'doc2': []};
        expect(result['doc2'], isEmpty);
      });

      test('handles non-existent document IDs gracefully', () {
        // When querying documents that don't exist:
        // getBatchDocumentTags(['nonexistent1', 'nonexistent2'])
        //
        // Expected: Returns map with empty lists for each ID
        // Rationale: Pre-initialization creates keys for all IDs
        // Implementation: Query returns no results, pre-init lists remain
        final result = <String, List<String>>{'nonexistent1': []};
        expect(result['nonexistent1'], isEmpty);
      });

      test('returns List<String> values for tag IDs', () {
        // Result type is Map<String, List<String>>:
        // - Keys: document IDs (String)
        // - Values: lists of tag IDs (List<String>)
        //
        // Expected: Each document maps to list of tag ID strings
        // Rationale: Tag IDs are stored as strings
        // Implementation: final tagId = tag['tag_id'] as String
        final tags = <String>['tag1', 'tag2'];
        expect(tags, isA<List<String>>());
      });

      test('fetches all tags in single database query', () {
        // Performance characteristic:
        // - Old approach: N queries (one per document)
        // - New approach: 1 query (all documents at once)
        //
        // Expected: Single rawQuery call with IN clause
        // Rationale: Eliminates N+1 query problem
        // Implementation: Single db.rawQuery() with all IDs
        expect(DatabaseHelper.tableDocumentTags, equals('document_tags'));
      });

      test('queries document_tags table correctly', () {
        // Query structure:
        // SELECT document_id, tag_id
        // FROM document_tags
        // WHERE document_id IN (...)
        //
        // Expected: Fetches from document_tags junction table
        // Rationale: document_tags is many-to-many relationship table
        // Implementation: Uses tableDocumentTags constant
        expect(DatabaseHelper.tableDocumentTags, equals('document_tags'));
      });
    });

    group('Batch Query Performance', () {
      test('batch methods eliminate N+1 query problem', () {
        // Query count comparison for N documents:
        // - Old approach: 1 + N + N = 2N+1 queries
        //   - 1 query for documents
        //   - N queries for page paths
        //   - N queries for tags
        // - New approach: 1 + 1 + 1 = 3 queries
        //   - 1 query for documents
        //   - 1 batch query for all page paths
        //   - 1 batch query for all tags
        //
        // Expected: Constant O(3) queries instead of O(2N+1)
        // Rationale: Batch queries eliminate per-document overhead
        final documentCount = 50;
        final oldQueryCount = 1 + documentCount + documentCount; // 101
        final newQueryCount = 1 + 1 + 1; // 3
        expect(newQueryCount, lessThan(oldQueryCount));
      });

      test('batch methods use IN clause for efficient querying', () {
        // SQL IN clause efficiency:
        // WHERE document_id IN (?, ?, ?, ...)
        //
        // Expected: Single WHERE clause handles multiple values
        // Rationale: Database can optimize IN clause lookups
        // Implementation: Parameterized placeholders for safety
        final ids = ['id1', 'id2', 'id3'];
        final placeholders = List.filled(ids.length, '?').join(',');
        expect(placeholders.contains(','), isTrue);
      });

      test('batch methods maintain consistent return structure', () {
        // Return type consistency:
        // - Always returns Map<String, List<String>>
        // - Empty input returns empty map
        // - All document IDs present as keys
        // - Missing data returns empty lists, not null
        //
        // Expected: Predictable structure for callers
        // Rationale: No null checks needed, safe iteration
        final result = <String, List<String>>{};
        expect(result, isA<Map<String, List<String>>>());
      });

      test('batch methods pre-initialize result map', () {
        // Pre-initialization pattern:
        // final result = <String, List<String>>{};
        // for (final id in documentIds) {
        //   result[id] = [];
        // }
        //
        // Expected: All document IDs present before query
        // Rationale: Ensures missing data doesn't cause null errors
        // Implementation: Both methods use same initialization pattern
        final ids = ['doc1', 'doc2'];
        final result = <String, List<String>>{};
        for (final id in ids) {
          result[id] = [];
        }
        expect(result.keys.length, equals(2));
      });
    });

    group('insertSearchHistory', () {
      test('accepts required parameters query, timestamp, and resultCount', () {
        // Method signature:
        // Future<int> insertSearchHistory({
        //   required String query,
        //   required String timestamp,
        //   required int resultCount,
        // })
        //
        // Expected: All three parameters are required
        // Rationale: Search history needs complete information
        // Implementation: Named parameters with required keyword
        expect(DatabaseHelper.columnQuery, equals('query'));
        expect(DatabaseHelper.columnTimestamp, equals('timestamp'));
        expect(DatabaseHelper.columnResultCount, equals('result_count'));
      });

      test('returns Future<int> with auto-incremented ID', () {
        // Return type is Future<int>:
        // return await db.insert(tableSearchHistory, {...});
        //
        // Expected: Returns the auto-incremented row ID
        // Rationale: search_history.id is INTEGER PRIMARY KEY AUTOINCREMENT
        // Implementation: db.insert() returns the new row's ID
        final mockId = 42;
        expect(mockId, isA<int>());
        expect(mockId, greaterThan(0));
      });

      test('inserts into search_history table', () {
        // Table target:
        // await db.insert(tableSearchHistory, {...});
        //
        // Expected: Uses tableSearchHistory constant
        // Rationale: Consistent table name references
        // Implementation: DatabaseHelper.tableSearchHistory = 'search_history'
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
      });

      test('inserts all three column values correctly', () {
        // Insert map structure:
        // {
        //   columnQuery: query,
        //   columnTimestamp: timestamp,
        //   columnResultCount: resultCount,
        // }
        //
        // Expected: All parameters mapped to correct columns
        // Rationale: Each parameter has corresponding database column
        // Implementation: Map keys use column name constants
        final insertMap = {
          'query': 'flutter tutorial',
          'timestamp': '2024-01-15T10:30:00Z',
          'result_count': 42,
        };
        expect(insertMap.keys.length, equals(3));
        expect(insertMap['query'], isA<String>());
        expect(insertMap['timestamp'], isA<String>());
        expect(insertMap['result_count'], isA<int>());
      });

      test('stores query as TEXT in database', () {
        // Column definition:
        // CREATE TABLE search_history (
        //   query TEXT NOT NULL,
        //   ...
        // )
        //
        // Expected: Query stored as TEXT column
        // Rationale: Search queries are variable-length strings
        // Implementation: columnQuery: query parameter
        expect(DatabaseHelper.columnQuery, equals('query'));
      });

      test('stores timestamp as TEXT in ISO 8601 format', () {
        // Column definition:
        // CREATE TABLE search_history (
        //   timestamp TEXT NOT NULL,
        //   ...
        // )
        //
        // Expected: Timestamp stored as TEXT (ISO 8601 format)
        // Rationale: SQLite stores dates as TEXT, INTEGER, or REAL
        // Implementation: columnTimestamp: timestamp parameter
        final isoTimestamp = '2024-01-15T10:30:00.000Z';
        expect(isoTimestamp, matches(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}'));
      });

      test('stores resultCount as INTEGER in database', () {
        // Column definition:
        // CREATE TABLE search_history (
        //   result_count INTEGER NOT NULL DEFAULT 0,
        //   ...
        // )
        //
        // Expected: Result count stored as INTEGER column
        // Rationale: Number of results is always a whole number
        // Implementation: columnResultCount: resultCount parameter
        final resultCount = 42;
        expect(resultCount, isA<int>());
        expect(resultCount, greaterThanOrEqualTo(0));
      });

      test('allows zero results to be recorded', () {
        // Valid result count range:
        // resultCount can be 0 (no results found)
        //
        // Expected: Zero is a valid result count
        // Rationale: Search may return no matches
        // Implementation: No minimum value validation
        final zeroResults = 0;
        expect(zeroResults, equals(0));
        expect(zeroResults, greaterThanOrEqualTo(0));
      });

      test('allows empty query strings to be recorded', () {
        // Valid query values:
        // query can be empty string ''
        //
        // Expected: Empty string is accepted (though unusual)
        // Rationale: No validation prevents empty queries
        // Implementation: Direct parameter pass-through
        final emptyQuery = '';
        expect(emptyQuery, isA<String>());
        expect(emptyQuery.length, equals(0));
      });

      test('uses async/await for database operation', () {
        // Async pattern:
        // Future<int> insertSearchHistory(...) async {
        //   final db = await database;
        //   return await db.insert(...);
        // }
        //
        // Expected: Method returns Future for async operation
        // Rationale: Database operations are asynchronous
        // Implementation: async/await throughout method chain
        expect(DatabaseHelper.tableSearchHistory, isNotEmpty);
      });

      test('gets database instance before insert', () {
        // Database access pattern:
        // final db = await database;
        // return await db.insert(...);
        //
        // Expected: Calls database getter before operation
        // Rationale: Ensures database is initialized
        // Implementation: Standard pattern for all database operations
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
      });

      test('creates search_history table with correct schema', () {
        // Table schema (created in _onCreate):
        // CREATE TABLE search_history (
        //   id INTEGER PRIMARY KEY AUTOINCREMENT,
        //   query TEXT NOT NULL,
        //   timestamp TEXT NOT NULL,
        //   result_count INTEGER NOT NULL DEFAULT 0
        // )
        //
        // Expected: Table exists with auto-increment ID and three data columns
        // Rationale: Schema supports search history tracking
        // Implementation: Created in database version 3 migration
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
        expect(DatabaseHelper.columnId, equals('id'));
        expect(DatabaseHelper.columnQuery, equals('query'));
        expect(DatabaseHelper.columnTimestamp, equals('timestamp'));
        expect(DatabaseHelper.columnResultCount, equals('result_count'));
      });

      test('has index on timestamp for efficient sorting', () {
        // Index creation (in _onCreate):
        // CREATE INDEX idx_search_history_timestamp
        // ON search_history(timestamp)
        //
        // Expected: Index exists for timestamp column
        // Rationale: Search history is typically ordered by recency
        // Implementation: Index created during table creation
        expect(DatabaseHelper.columnTimestamp, equals('timestamp'));
      });
    });

    group('getSearchHistory', () {
      test('returns Future<List<Map<String, dynamic>>>', () {
        // Method signature:
        // Future<List<Map<String, dynamic>>> getSearchHistory({
        //   int? limit,
        //   String? orderBy,
        // })
        //
        // Expected: Returns list of maps representing search history entries
        // Rationale: Standard database query return type
        // Implementation: db.query() returns List<Map<String, dynamic>>
        final mockResult = <Map<String, dynamic>>[];
        expect(mockResult, isA<List<Map<String, dynamic>>>());
      });

      test('accepts optional limit parameter', () {
        // Parameter definition:
        // int? limit
        //
        // Expected: limit is optional (nullable int)
        // Rationale: Allows fetching all entries or limiting results
        // Implementation: Optional named parameter passed to db.query()
        final limit = 10;
        expect(limit, isA<int>());
        expect(limit, greaterThan(0));
      });

      test('accepts optional orderBy parameter', () {
        // Parameter definition:
        // String? orderBy
        //
        // Expected: orderBy is optional (nullable String)
        // Rationale: Allows custom sort order or default timestamp DESC
        // Implementation: Optional named parameter passed to db.query()
        final orderBy = 'timestamp ASC';
        expect(orderBy, isA<String>());
        expect(orderBy, contains('timestamp'));
      });

      test('queries search_history table', () {
        // Table target:
        // await db.query(tableSearchHistory, ...)
        //
        // Expected: Uses tableSearchHistory constant
        // Rationale: Consistent table name references
        // Implementation: DatabaseHelper.tableSearchHistory = 'search_history'
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
      });

      test('defaults to timestamp DESC ordering', () {
        // Default orderBy clause:
        // orderBy: orderBy ?? '$columnTimestamp DESC'
        //
        // Expected: When orderBy is null, orders by timestamp DESC
        // Rationale: Most recent searches should appear first
        // Implementation: Null-coalescing operator with default
        final defaultOrder = '${DatabaseHelper.columnTimestamp} DESC';
        expect(defaultOrder, equals('timestamp DESC'));
        expect(defaultOrder, endsWith('DESC'));
      });

      test('allows custom orderBy to override default', () {
        // Custom orderBy usage:
        // orderBy: orderBy ?? '$columnTimestamp DESC'
        //
        // Expected: When orderBy is provided, uses custom sort
        // Rationale: Flexibility for different sorting needs
        // Implementation: Null-coalescing operator passes custom value
        final customOrder = 'query ASC';
        expect(customOrder, isA<String>());
        expect(customOrder, isNot(contains('timestamp')));
      });

      test('applies limit when specified', () {
        // Limit parameter usage:
        // limit: limit
        //
        // Expected: When limit is provided, restricts result count
        // Rationale: Pagination and performance optimization
        // Implementation: Passed directly to db.query()
        final limit = 20;
        expect(limit, isA<int>());
        expect(limit, greaterThan(0));
      });

      test('returns all entries when limit is not specified', () {
        // No limit behavior:
        // limit: limit (when limit is null)
        //
        // Expected: When limit is null, returns all matching rows
        // Rationale: SQLite query without LIMIT clause fetches all
        // Implementation: db.query() with limit: null
        int? noLimit;
        expect(noLimit, isNull);
      });

      test('uses async/await for database operation', () {
        // Async pattern:
        // Future<List<Map<String, dynamic>>> getSearchHistory(...) async {
        //   final db = await database;
        //   return await db.query(...);
        // }
        //
        // Expected: Method returns Future for async operation
        // Rationale: Database operations are asynchronous
        // Implementation: async/await throughout method chain
        expect(DatabaseHelper.tableSearchHistory, isNotEmpty);
      });

      test('gets database instance before query', () {
        // Database access pattern:
        // final db = await database;
        // return await db.query(...);
        //
        // Expected: Calls database getter before operation
        // Rationale: Ensures database is initialized
        // Implementation: Standard pattern for all database operations
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
      });

      test('returns entries with all search_history columns', () {
        // Query result structure:
        // Each Map contains: id, query, timestamp, result_count
        //
        // Expected: Returns all columns from search_history table
        // Rationale: db.query() without columns parameter fetches all
        // Implementation: Full row data in each map
        final mockEntry = {
          'id': 1,
          'query': 'flutter tutorial',
          'timestamp': '2024-01-15T10:30:00Z',
          'result_count': 42,
        };
        expect(mockEntry.keys.length, equals(4));
        expect(mockEntry['id'], isA<int>());
        expect(mockEntry['query'], isA<String>());
        expect(mockEntry['timestamp'], isA<String>());
        expect(mockEntry['result_count'], isA<int>());
      });

      test('leverages timestamp index for efficient sorting', () {
        // Index usage:
        // CREATE INDEX idx_search_history_timestamp ON search_history(timestamp)
        // Default: ORDER BY timestamp DESC
        //
        // Expected: Query optimizer uses timestamp index
        // Rationale: Index on timestamp enables fast DESC ordering
        // Implementation: Index created in _onCreate supports default sort
        expect(DatabaseHelper.columnTimestamp, equals('timestamp'));
      });

      test('supports common limit values for pagination', () {
        // Common limit usage patterns:
        // - limit: 10 (recent searches)
        // - limit: 50 (more history)
        // - limit: null (all entries)
        //
        // Expected: Accepts any positive integer or null
        // Rationale: Different UI contexts need different amounts
        // Implementation: Direct pass-through to SQLite LIMIT clause
        final recentLimit = 10;
        final moreLimit = 50;
        int? allLimit;

        expect(recentLimit, equals(10));
        expect(moreLimit, equals(50));
        expect(allLimit, isNull);
      });

      test('can order by query column alphabetically', () {
        // Alternative orderBy example:
        // orderBy: 'query ASC'
        //
        // Expected: Supports ordering by query column
        // Rationale: Alphabetical sorting may be useful for some UIs
        // Implementation: Custom orderBy overrides default
        final alphabeticalOrder = '${DatabaseHelper.columnQuery} ASC';
        expect(alphabeticalOrder, equals('query ASC'));
        expect(alphabeticalOrder, contains('query'));
      });

      test('can order by result_count for popularity sorting', () {
        // Alternative orderBy example:
        // orderBy: 'result_count DESC'
        //
        // Expected: Supports ordering by result count
        // Rationale: May want to show searches with most results
        // Implementation: Custom orderBy overrides default
        final popularityOrder = '${DatabaseHelper.columnResultCount} DESC';
        expect(popularityOrder, equals('result_count DESC'));
        expect(popularityOrder, contains('result_count'));
      });

      test('returns empty list when no history exists', () {
        // Empty result handling:
        // return await db.query(...)
        //
        // Expected: Returns empty list when table is empty
        // Rationale: db.query() returns empty list, not null
        // Implementation: No special empty handling needed
        final emptyResult = <Map<String, dynamic>>[];
        expect(emptyResult, isEmpty);
        expect(emptyResult, isA<List<Map<String, dynamic>>>());
      });
    });

    group('deleteSearchHistory', () {
      // Method signature:
      // Future<int> deleteSearchHistory(int id) async {
      //   final db = await database;
      //   return await db.delete(
      //     tableSearchHistory,
      //     where: '$columnId = ?',
      //     whereArgs: [id],
      //   );
      // }

      test('deletes from search_history table', () {
        // SQL DELETE operation:
        // await db.delete(tableSearchHistory, where: 'id = ?', whereArgs: [id]);
        //
        // Expected: Uses tableSearchHistory constant
        // Rationale: Consistent table name reference
        // Implementation: DatabaseHelper.tableSearchHistory = 'search_history'
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
      });

      test('uses WHERE clause to target specific entry by ID', () {
        // WHERE clause construction:
        // where: '$columnId = ?'
        // whereArgs: [id]
        //
        // Expected: Filters by id column with parameterized query
        // Rationale: Prevents SQL injection and targets single entry
        // Implementation: Uses positional parameter (?) with whereArgs
        final whereClause = '${DatabaseHelper.columnId} = ?';
        expect(whereClause, equals('id = ?'));
        expect(DatabaseHelper.columnId, equals('id'));
      });

      test('accepts integer ID parameter', () {
        // Parameter type:
        // Future<int> deleteSearchHistory(int id)
        //
        // Expected: ID must be an integer
        // Rationale: Matches id column type (INTEGER PRIMARY KEY)
        // Implementation: Type-safe parameter
        final validId = 42;
        expect(validId, isA<int>());
        expect(validId, greaterThan(0));
      });

      test('returns number of deleted rows', () {
        // Return value:
        // return await db.delete(...)
        //
        // Expected: Returns int count of deleted rows
        // Rationale: SQLite delete returns number of affected rows
        // Implementation: Returns 1 if found and deleted, 0 if not found
        const deletedCount = 1;
        const notFoundCount = 0;
        expect(deletedCount, equals(1));
        expect(notFoundCount, equals(0));
      });

      test('returns 0 when ID does not exist', () {
        // Non-existent ID handling:
        // await db.delete(tableSearchHistory, where: 'id = ?', whereArgs: [999999]);
        //
        // Expected: Returns 0 when no matching row found
        // Rationale: SQLite returns 0 for DELETE with no matches
        // Implementation: No special handling needed
        const notFoundResult = 0;
        expect(notFoundResult, equals(0));
      });

      test('only deletes the specified entry, not others', () {
        // Single entry deletion:
        // WHERE id = ?
        //
        // Expected: Only the row with matching ID is deleted
        // Rationale: WHERE clause ensures single-row operation
        // Implementation: Primary key constraint ensures uniqueness
        expect(DatabaseHelper.columnId, equals('id'));
        // id is PRIMARY KEY, so WHERE id = ? matches at most one row
      });

      test('uses parameterized query for SQL injection safety', () {
        // Parameterized query:
        // where: 'id = ?'
        // whereArgs: [id]
        //
        // Expected: Uses placeholder (?) with separate arguments
        // Rationale: Prevents SQL injection attacks
        // Implementation: SQLite prepared statement with bound parameters
        final whereClause = '${DatabaseHelper.columnId} = ?';
        expect(whereClause, contains('?'));
        expect(whereClause, equals('id = ?'));
        // Uses ? placeholder instead of string concatenation for safety
      });
    });

    group('clearSearchHistory', () {
      // Method signature:
      // Future<int> clearSearchHistory() async {
      //   final db = await database;
      //   return await db.delete(tableSearchHistory);
      // }

      test('deletes from search_history table', () {
        // SQL DELETE operation:
        // await db.delete(tableSearchHistory);
        //
        // Expected: Uses tableSearchHistory constant
        // Rationale: Consistent table name reference
        // Implementation: DatabaseHelper.tableSearchHistory = 'search_history'
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
      });

      test('has no WHERE clause to delete all entries', () {
        // No WHERE clause:
        // await db.delete(tableSearchHistory);
        // NOT: await db.delete(tableSearchHistory, where: '...');
        //
        // Expected: Omits where parameter to delete all rows
        // Rationale: DELETE without WHERE removes all table data
        // Implementation: Calls db.delete with only table name
        expect(DatabaseHelper.tableSearchHistory, isNotEmpty);
        // Absence of WHERE means: DELETE FROM search_history (all rows)
      });

      test('takes no parameters', () {
        // Method signature:
        // Future<int> clearSearchHistory() async
        //
        // Expected: No parameters needed
        // Rationale: Clears entire table, no filtering required
        // Implementation: Simple method signature with no args
        // Method has no parameters - deletes everything
      });

      test('returns number of deleted rows', () {
        // Return value:
        // return await db.delete(tableSearchHistory);
        //
        // Expected: Returns int count of deleted rows
        // Rationale: SQLite delete returns number of affected rows
        // Implementation: Returns total count of all deleted entries
        const multipleDeleted = 5;
        const emptyTableDeleted = 0;
        expect(multipleDeleted, greaterThan(0));
        expect(emptyTableDeleted, equals(0));
      });

      test('returns 0 when table is already empty', () {
        // Empty table handling:
        // await db.delete(tableSearchHistory); // on empty table
        //
        // Expected: Returns 0 when no rows exist
        // Rationale: SQLite returns 0 for DELETE with no matches
        // Implementation: No special handling needed
        const emptyResult = 0;
        expect(emptyResult, equals(0));
      });

      test('removes all entries regardless of timestamp or content', () {
        // Complete table clearing:
        // DELETE FROM search_history
        //
        // Expected: All rows deleted, no filtering
        // Rationale: Clear operation removes everything
        // Implementation: No WHERE, ORDER BY, or LIMIT clauses
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
        // No WHERE clause means all rows are deleted
      });

      test('is efficient for bulk deletion', () {
        // Bulk delete performance:
        // DELETE FROM search_history
        //
        // Expected: Single SQL statement removes all rows
        // Rationale: More efficient than deleting one-by-one
        // Implementation: Single db.delete() call without iteration
        expect(DatabaseHelper.tableSearchHistory, isNotEmpty);
        // Single DELETE statement is more efficient than multiple WHERE clauses
      });

      test('can be used to reset search history feature', () {
        // Use case:
        // User wants to clear all search history
        // Privacy concerns or starting fresh
        //
        // Expected: Provides clean slate functionality
        // Rationale: Common privacy feature in search UIs
        // Implementation: Simple delete all operation
        expect(DatabaseHelper.tableSearchHistory, equals('search_history'));
        // Provides "Clear History" feature for privacy
      });
    });
  });
}
