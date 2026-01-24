# FTS Search Functionality Verification Guide

## Overview

This guide provides comprehensive instructions for verifying that FTS (Full-Text Search) functionality works correctly with the SQLCipher encrypted database.

## What is FTS?

Full-Text Search (FTS) is a database feature that allows efficient searching of text content across multiple fields. AIScan uses FTS5 (with FTS4 fallback) to search across:
- Document titles
- Document descriptions
- OCR-extracted text from scanned documents

## Why This Matters

FTS virtual tables must be compatible with SQLCipher encryption. This verification ensures:
1. FTS module loads correctly with encrypted database
2. Search index stays synchronized with encrypted data
3. Search performance remains acceptable with encryption overhead
4. All search features (ranking, filters, multi-field search) work correctly

---

## Automated Tests

### Running the Integration Tests

Execute the comprehensive FTS integration test suite:

```bash
# Run all FTS encryption tests
flutter test test/integration/fts_encrypted_database_test.dart

# Run with verbose output
flutter test test/integration/fts_encrypted_database_test.dart --reporter=expanded
```

### Test Coverage

The automated tests verify:

✅ **FTS Module Availability**
- FTS5 or FTS4 module available with SQLCipher
- FTS virtual table created in encrypted database

✅ **Index Synchronization**
- FTS index updates when inserting documents
- FTS index updates when updating documents
- FTS index updates when deleting documents

✅ **Search Features**
- Multi-field search (title, description, OCR text)
- Special character handling
- Multi-word queries
- Relevance ranking (FTS5)
- Case-insensitive search
- Filter combinations (favorites, folders)

✅ **Performance**
- Search completes in reasonable time with encryption
- Performance acceptable with 50+ documents

✅ **Edge Cases**
- Empty search queries
- Documents with null OCR text
- Very long search queries
- Special characters in OCR content (numbers, symbols)

✅ **Encryption Verification**
- Database requires password to open
- Encryption key retrieved from SecureStorageService

---

## Manual Verification

### Prerequisites

1. Build and install the app on a test device:
   ```bash
   flutter run --profile
   ```

2. Ensure you have test documents ready to scan or import

### Test Scenario 1: Basic FTS Search

**Purpose:** Verify FTS search works with encrypted database

**Steps:**
1. Launch the AIScan app
2. Scan or import 3-5 documents with different content
3. Run OCR on all documents (wait for completion)
4. Navigate to the search screen
5. Search for a word that appears in one document's OCR text
6. Verify the correct document appears in results
7. Search for a word in a document title
8. Verify the correct document appears in results

**Expected Results:**
- ✅ Search returns relevant documents
- ✅ Results appear within 1-2 seconds
- ✅ Relevance ranking shows most relevant results first
- ✅ No error messages or crashes

### Test Scenario 2: Multi-Field Search

**Purpose:** Verify FTS searches across title, description, and OCR text

**Steps:**
1. Create a document with title "Invoice 2024"
2. Set description to "Annual tax documents"
3. Ensure OCR text contains "payment receipt"
4. Search for "invoice" → should find the document
5. Search for "tax" → should find the document
6. Search for "receipt" → should find the document
7. Search for "unrelated" → should NOT find the document

**Expected Results:**
- ✅ Searches in all three fields return the document
- ✅ Unrelated search returns no results
- ✅ Search is case-insensitive

### Test Scenario 3: OCR Content Search

**Purpose:** Verify sensitive OCR content is searchable but encrypted at rest

**Test Documents:**
- Bank statement with account numbers
- Medical record with patient info
- ID/Passport with document numbers

**Steps:**
1. Scan bank statement, run OCR
2. Search for account number from OCR text
3. Verify document is found
4. Scan medical record, run OCR
5. Search for patient name or medical term
6. Verify document is found
7. Scan ID/passport, run OCR
8. Search for document number
9. Verify document is found

**Expected Results:**
- ✅ All sensitive content is searchable
- ✅ Search results appear quickly
- ✅ Correct documents are returned
- ✅ No partial matches (unless intended)

### Test Scenario 4: Search with Filters

**Purpose:** Verify FTS works with favorite and folder filters

**Steps:**
1. Mark 2 documents as favorites
2. Search for a term that appears in both favorite and non-favorite documents
3. Enable "Favorites Only" filter
4. Verify only favorite documents appear
5. Create a folder "Medical Records"
6. Move some documents to the folder
7. Search within the folder only
8. Verify only documents in that folder appear

**Expected Results:**
- ✅ Favorites filter correctly limits results
- ✅ Folder filter correctly limits results
- ✅ Combined filters work correctly
- ✅ No performance degradation with filters

### Test Scenario 5: Special Characters and Numbers

**Purpose:** Verify FTS handles special content from OCR

**OCR Content to Test:**
- Phone numbers: "555-123-4567"
- Email addresses: "test@example.com"
- Currency: "$1,234.56"
- Dates: "2024-01-15"
- Reference numbers: "INV-2024-001"

**Steps:**
1. Scan documents with the above special content
2. Run OCR
3. Search for parts of each:
   - "555" for phone
   - "example" for email
   - "1234" for currency
   - "2024" for date
   - "INV" for reference

**Expected Results:**
- ✅ Special characters don't break search
- ✅ Partial number matches work
- ✅ Email components are searchable
- ✅ Currency amounts are searchable

### Test Scenario 6: Performance with Many Documents

**Purpose:** Verify FTS performance with encrypted database at scale

**Steps:**
1. Create/import 20+ documents
2. Run OCR on all documents
3. Perform search for common term
4. Measure response time (should be < 2 seconds)
5. Try complex multi-word search
6. Try search with multiple filters enabled

**Expected Results:**
- ✅ Search with 20+ docs completes in < 2 seconds
- ✅ No lag or stuttering in UI
- ✅ Results paginate smoothly if many results
- ✅ No memory issues or crashes

### Test Scenario 7: Index Synchronization

**Purpose:** Verify FTS index stays synchronized with database changes

**Steps:**
1. Create document "Test Doc" with OCR "original content"
2. Search for "original" → should find document
3. Update OCR text to "updated content"
4. Search for "original" → should NOT find document
5. Search for "updated" → SHOULD find document
6. Delete the document
7. Search for "updated" → should NOT find document

**Expected Results:**
- ✅ Index reflects insertions immediately
- ✅ Index reflects updates immediately
- ✅ Index reflects deletions immediately
- ✅ No stale results from old content

---

## Device-Level Verification

### Verify Database is Actually Encrypted

**Android:**
```bash
# Pull database from device
adb pull /data/data/com.example.aiscan/databases/aiscan.db ./test-db.db

# Try to open without password (should fail or show garbage)
sqlite3 ./test-db.db ".tables"

# Expected: Error or unreadable output

# Clean up
rm ./test-db.db
```

**iOS:**
```bash
# Use Xcode → Devices → Download Container
# Or use idevice tools to pull database

# Try to open without password (should fail)
sqlite3 ./aiscan.db ".tables"

# Expected: Error or unreadable output
```

**Expected Outcome:**
- ❌ Opening database without password SHOULD FAIL
- ❌ Attempting to read tables SHOULD FAIL or show garbage
- ✅ This proves database is encrypted

### Verify FTS Tables are Encrypted

**Android:**
```bash
# Pull database
adb pull /data/data/com.example.aiscan/databases/aiscan.db ./test-db.db

# Try to read FTS table content
sqlite3 ./test-db.db "SELECT * FROM documents_fts LIMIT 1;"

# Expected: Error or unreadable garbage

# Clean up
rm ./test-db.db
```

**Expected Outcome:**
- ❌ Reading FTS table content SHOULD FAIL
- ✅ This proves FTS index is encrypted along with data

---

## Troubleshooting

### Search Not Finding Expected Documents

**Possible Causes:**
1. OCR not completed yet → Check document OCR status
2. FTS index not synchronized → Restart app
3. Search query syntax issue → Try simpler query

**Solution:**
- Verify OCR status is "completed"
- Check database logs for FTS errors
- Try exact word match first before complex queries

### Search Performance Degradation

**Possible Causes:**
1. Too many documents without VACUUM → Optimize database
2. FTS index fragmented → Rebuild FTS index
3. Encryption overhead → Normal, should still be < 2s

**Solution:**
```dart
// In debug console or test
await dbHelper.database.execute('VACUUM;');
```

### FTS Module Not Available

**Possible Causes:**
1. SQLCipher build missing FTS extension
2. Platform-specific issue

**Check FTS Version:**
```dart
print('FTS Version: ${DatabaseHelper.ftsVersion}');
// Should print: 5 or 4
// If prints: 0 → FTS not available
```

**Solution:**
- Verify sqflite_sqlcipher dependency is correct version
- Check build logs for compilation errors
- Report issue if FTS consistently unavailable

---

## Acceptance Criteria Checklist

Mark each item when verified:

### Automated Tests
- [ ] All integration tests pass
- [ ] No flaky test failures
- [ ] Code coverage > 80% for FTS code

### Manual Testing
- [ ] Basic search finds documents
- [ ] Multi-field search works (title, description, OCR)
- [ ] OCR content is fully searchable
- [ ] Search with filters works correctly
- [ ] Special characters handled correctly
- [ ] Performance acceptable (< 2 seconds with 20+ docs)
- [ ] Index synchronization works (insert, update, delete)

### Encryption Verification
- [ ] Database file is encrypted (cannot open without password)
- [ ] FTS index is encrypted (cannot read without password)
- [ ] App can search encrypted content normally
- [ ] No performance degradation beyond acceptable limits

### Edge Cases
- [ ] Empty queries handled gracefully
- [ ] Null OCR text doesn't break search
- [ ] Very long queries don't crash
- [ ] Special OCR content searchable (numbers, symbols, currency)

### Production Readiness
- [ ] No console errors during search
- [ ] No memory leaks with repeated searches
- [ ] Search works after app restart
- [ ] Search works after database migration

---

## Success Criteria

✅ **ALL of the following must be true:**

1. Automated integration tests pass 100%
2. Manual test scenarios all pass
3. Database encryption verified at device level
4. FTS search performance < 2 seconds with 20+ documents
5. No crashes or errors during any test scenario
6. FTS index stays synchronized with all CRUD operations
7. All search features work correctly with encrypted database

---

## Additional Notes

### FTS5 vs FTS4

- **FTS5** (preferred): Better performance, built-in ranking, modern syntax
- **FTS4** (fallback): Wider compatibility, basic search, no ranking
- **Fallback to LIKE** (last resort): No FTS module, uses LIKE operator

The app automatically detects and uses the best available option.

### Encryption Impact on Performance

SQLCipher adds minimal overhead to FTS operations:
- Encryption/decryption happens transparently
- FTS index is stored encrypted
- Search queries decrypt on-the-fly
- Performance impact: typically < 10% slower than unencrypted

### Security Considerations

✅ **What IS encrypted:**
- Document metadata (title, description)
- OCR text content
- FTS index data
- All database tables

✅ **What protects the encryption:**
- AES-256 encryption
- Key stored in platform-secure storage (Keychain/Keystore)
- Same key used for file and database encryption

---

## Reporting Issues

If any test fails, document:
1. Test scenario that failed
2. Expected vs actual behavior
3. Device/OS information
4. App version and build number
5. Logs from the failure
6. Steps to reproduce

File issues with label: `encryption`, `fts`, `search`

---

## Conclusion

This verification ensures that FTS search functionality works seamlessly with SQLCipher database encryption, maintaining both security and usability.

**Next Steps After Verification:**
1. Proceed to subtask-4-3: Test all CRUD operations
2. Proceed to subtask-4-4: Test data migration integrity
3. Complete final verification before production release

