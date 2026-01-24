# Database Migration Integrity Verification Guide

## Overview

This guide provides comprehensive instructions for verifying the integrity of the database migration from unencrypted SQLite to encrypted SQLCipher. The migration process must preserve all data, relationships, and functionality while adding encryption.

## Critical Requirements

The migration MUST:
- ✅ Preserve all row counts across all tables
- ✅ Maintain folder structure and nested relationships
- ✅ Preserve all document metadata (titles, descriptions, OCR text)
- ✅ Maintain tag associations (many-to-many relationships)
- ✅ Preserve foreign key relationships and cascade behaviors
- ✅ Handle multi-page documents correctly
- ✅ Preserve sensitive OCR content (PII, financial data, medical records)
- ✅ Create backup before migration
- ✅ Support rollback on failure
- ✅ Complete in reasonable time (< 10s for typical dataset)

## Automated Testing

### Run Integration Tests

```bash
# Run all migration integrity tests
flutter test test/integration/migration_integrity_test.dart

# Run specific test group
flutter test test/integration/migration_integrity_test.dart --name "Row Count Verification"
flutter test test/integration/migration_integrity_test.dart --name "Folder Structure Preservation"
flutter test test/integration/migration_integrity_test.dart --name "Tag Association Preservation"
```

### Test Coverage

The automated test suite includes 15+ comprehensive tests:

**Row Count Verification (2 tests)**
- All rows migrated from all tables
- Empty tables handled gracefully

**Folder Structure Preservation (2 tests)**
- Folder hierarchy and nested relationships preserved
- Document-to-folder relationships maintained

**Document Data Preservation (3 tests)**
- All metadata fields preserved
- OCR text content intact (including sensitive data)
- Multi-page document structure maintained

**Tag Association Preservation (3 tests)**
- All tag definitions preserved
- Document-tag associations maintained
- Multiple tags per document handled correctly

**Foreign Key Relationships (2 tests)**
- CASCADE DELETE behavior preserved
- SET NULL behavior preserved

**Complex Scenarios (2 tests)**
- Real-world scenario with all features
- Post-migration database functionality verified

**Backup & Rollback (2 tests)**
- Backup created before migration
- Backup deleted after success

**Performance (1 test)**
- Migration completes in reasonable time

## Manual Verification

### Scenario 1: Basic Migration Verification

**Objective:** Verify migration runs successfully and preserves data

**Steps:**
1. Install app with old unencrypted database containing real data
2. Update to new version with SQLCipher support
3. Launch app and observe migration process in logs
4. Verify all documents still visible in app
5. Check that document count matches pre-migration count

**Expected Results:**
- ✅ Migration completes successfully
- ✅ No data loss
- ✅ All documents accessible
- ✅ App functions normally

**Verification Commands:**
```bash
# Before migration - count rows in old database
adb shell "run-as com.example.aiscan sqlite3 /data/data/com.example.aiscan/databases/aiscan.db 'SELECT COUNT(*) FROM documents;'"

# After migration - verify same count
# (Will fail to open directly - proves encryption!)
```

### Scenario 2: Folder Structure Verification

**Objective:** Verify folder hierarchy preserved

**Steps:**
1. Before migration, note folder structure:
   - Root folders
   - Nested folders
   - Documents in each folder
2. Run migration
3. Navigate folder structure in app
4. Verify all folders present and correctly nested
5. Verify documents in correct folders

**Expected Results:**
- ✅ All folders visible
- ✅ Nested folders in correct parent
- ✅ Documents in correct folders
- ✅ Folder colors/icons preserved

### Scenario 3: OCR Content Verification

**Objective:** Verify sensitive OCR text is preserved and encrypted

**Steps:**
1. Before migration, note documents with OCR content
2. Record sample OCR text from key documents
3. Run migration
4. Open documents in app and verify OCR text
5. Use search to find documents by OCR content
6. Attempt to read database file directly (should fail)

**Expected Results:**
- ✅ All OCR text preserved
- ✅ Search finds documents by OCR content
- ✅ Database file unreadable without password
- ✅ OCR text visible in app

**Test Cases:**
- Bank statements with account numbers
- Passports with ID numbers
- Tax returns with SSN
- Medical records with health data

### Scenario 4: Tag Association Verification

**Objective:** Verify tags and associations preserved

**Steps:**
1. Before migration, note:
   - Total tag count
   - Documents with multiple tags
   - Tag colors and names
2. Run migration
3. View tags list in app
4. Filter documents by tag
5. Verify documents have correct tags

**Expected Results:**
- ✅ All tags present
- ✅ Tag colors/names preserved
- ✅ Documents have correct tags
- ✅ Filter by tag works correctly

### Scenario 5: Multi-Page Document Verification

**Objective:** Verify multi-page documents preserved

**Steps:**
1. Before migration, note multi-page documents and page counts
2. Run migration
3. Open multi-page documents in app
4. Verify all pages present and in correct order
5. Navigate through pages

**Expected Results:**
- ✅ All pages present
- ✅ Pages in correct order
- ✅ Page images load correctly
- ✅ Page count matches original

### Scenario 6: Favorite Status Verification

**Objective:** Verify favorite flags preserved

**Steps:**
1. Before migration, note favorite documents and folders
2. Run migration
3. View favorites list in app
4. Verify all favorites present

**Expected Results:**
- ✅ Favorite documents preserved
- ✅ Favorite folders preserved
- ✅ Favorites filter works

### Scenario 7: Backup and Rollback Verification

**Objective:** Verify backup mechanism works

**Steps:**
1. Before migration, locate database file
2. Run migration and note backup creation
3. Verify backup file exists
4. Complete migration successfully
5. Verify backup deleted after success

**Alternative - Test Rollback:**
1. Create scenario that causes migration to fail
2. Verify backup is restored automatically
3. Verify app works with restored database

**Expected Results:**
- ✅ Backup created before migration
- ✅ Backup has same size as original
- ✅ Backup deleted after success
- ✅ Rollback restores on failure

### Scenario 8: Search History Verification

**Objective:** Verify search history preserved

**Steps:**
1. Before migration, perform several searches
2. Note search history entries
3. Run migration
4. View search history in app
5. Verify all searches present

**Expected Results:**
- ✅ Search history preserved
- ✅ Search terms intact
- ✅ Result counts preserved
- ✅ Timestamps preserved

### Scenario 9: Signature Preservation

**Objective:** Verify signatures preserved (if used)

**Steps:**
1. Before migration, note saved signatures
2. Run migration
3. View signatures list in app
4. Verify all signatures present

**Expected Results:**
- ✅ All signatures present
- ✅ Signature names preserved
- ✅ Signature images accessible

## Database-Level Verification

### Row Count Comparison

Compare row counts before and after migration:

```sql
-- Tables to verify:
SELECT COUNT(*) FROM folders;
SELECT COUNT(*) FROM documents;
SELECT COUNT(*) FROM document_pages;
SELECT COUNT(*) FROM tags;
SELECT COUNT(*) FROM document_tags;
SELECT COUNT(*) FROM signatures;
SELECT COUNT(*) FROM search_history;
```

### Relationship Verification

Verify foreign key relationships:

```sql
-- Verify all documents reference valid folders (or NULL)
SELECT COUNT(*)
FROM documents d
LEFT JOIN folders f ON d.folder_id = f.id
WHERE d.folder_id IS NOT NULL AND f.id IS NULL;
-- Should return 0

-- Verify all document_pages reference valid documents
SELECT COUNT(*)
FROM document_pages p
LEFT JOIN documents d ON p.document_id = d.id
WHERE d.id IS NULL;
-- Should return 0

-- Verify all document_tags reference valid documents and tags
SELECT COUNT(*)
FROM document_tags dt
LEFT JOIN documents d ON dt.document_id = d.id
LEFT JOIN tags t ON dt.tag_id = t.id
WHERE d.id IS NULL OR t.id IS NULL;
-- Should return 0
```

### Sample Data Verification

Verify sample records match:

```sql
-- Get first document from each table (before and after)
SELECT * FROM documents ORDER BY created_at ASC LIMIT 1;
SELECT * FROM folders ORDER BY created_at ASC LIMIT 1;
SELECT * FROM tags ORDER BY created_at ASC LIMIT 1;
```

## Performance Benchmarks

### Expected Migration Times

| Data Size | Documents | Expected Time |
|-----------|-----------|---------------|
| Small     | < 100     | < 2 seconds   |
| Medium    | 100-1000  | 2-5 seconds   |
| Large     | 1000-5000 | 5-10 seconds  |
| Very Large| > 5000    | 10-30 seconds |

### Performance Test

```bash
# Monitor migration time in logs
adb logcat | grep "Migration completed"
# Output: "Migration completed successfully: XXX rows migrated"
```

## Troubleshooting

### Migration Fails

**Symptom:** Migration returns success: false

**Diagnosis:**
1. Check error message in MigrationResult
2. Review logs for specific failure point
3. Verify backup was created
4. Check if backup was restored

**Solution:**
- App should automatically restore from backup
- Fix underlying issue (disk space, permissions, etc.)
- Retry migration

### Row Count Mismatch

**Symptom:** Different number of rows in new database

**Diagnosis:**
1. Run row count comparison queries
2. Identify which table has mismatch
3. Check migration logs for errors

**Solution:**
- Rollback and retry migration
- Investigate specific table copy failure

### Backup Not Deleted

**Symptom:** Backup file remains after migration

**Diagnosis:**
1. Check if migration completed successfully
2. Verify deleteBackup() was called
3. Check file permissions

**Solution:**
- Manually delete backup if migration verified successful
- Investigate why automatic deletion failed

### Database Not Encrypted

**Symptom:** Can open database with standard sqlite3

**Diagnosis:**
1. Verify password parameter used in openDatabase
2. Check encryption key retrieval
3. Verify using sqflite_sqlcipher package

**Solution:**
- Verify correct package imported
- Check SecureStorageService integration
- Retry migration

## Acceptance Criteria Checklist

Before marking migration as successful:

- [ ] All automated tests pass
- [ ] Row counts match for all tables
- [ ] Folder structure preserved and verified
- [ ] Document metadata intact
- [ ] OCR text preserved (including sensitive content)
- [ ] Tag associations maintained
- [ ] Multi-page documents complete
- [ ] Foreign key relationships work
- [ ] Cascade delete behavior correct
- [ ] SET NULL behavior correct
- [ ] Backup created before migration
- [ ] Backup deleted after success
- [ ] Migration completes in < 10 seconds
- [ ] Database requires password to open
- [ ] App functions normally with encrypted DB
- [ ] Search works with encrypted data
- [ ] CRUD operations work
- [ ] No data loss detected

## Security Verification

- [ ] Database file is encrypted
- [ ] Cannot open with standard sqlite3
- [ ] OCR text encrypted at rest
- [ ] Metadata encrypted at rest
- [ ] Encryption key from SecureStorageService
- [ ] Same key as file encryption

## Next Steps

After successful migration verification:
1. Delete backup file (if not auto-deleted)
2. Proceed to Phase 5 cleanup tasks
3. Update documentation
4. Deploy to production

## References

- Implementation Plan: `.auto-claude/specs/030-encrypt-sqlite-database-with-sqlcipher/implementation_plan.json`
- Migration Helper: `lib/core/storage/database_migration_helper.dart`
- Integration Tests: `test/integration/migration_integrity_test.dart`
- Database Helper: `lib/core/storage/database_helper.dart`
