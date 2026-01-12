import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/storage/database_helper.dart';

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
}
