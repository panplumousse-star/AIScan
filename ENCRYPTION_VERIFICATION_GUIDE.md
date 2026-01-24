# Database Encryption Verification Guide

## Task: subtask-4-1 - Test Database Encryption with Manual Verification

This guide provides step-by-step instructions to verify that the SQLite database is properly encrypted using SQLCipher.

## Prerequisites

- Flutter development environment set up
- Android device or emulator (for testing)
- `sqlite3` command-line tool installed
- `adb` (Android Debug Bridge) installed

## Verification Steps

### Step 1: Build and Run the Application

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Run the application on your device/emulator
flutter run
```

### Step 2: Create Test Documents

1. Launch the app on your device/emulator
2. Create 2-3 test documents with the following:
   - Document titles (e.g., "Test Document 1", "Encrypted Test")
   - Document descriptions (e.g., "Testing database encryption")
   - Add some OCR text content (scan a document or manually add text)
   - Create folders and organize documents
   - Add tags to documents
   - Mark some as favorites

### Step 3: Locate the Database File

The database file location varies by platform:

**Android:**
```bash
# Find the app's data directory
adb shell run-as com.example.aiscan ls -la /data/data/com.example.aiscan/databases/

# The database file should be named: aiscan.db
```

**iOS Simulator:**
```bash
# Find the app's container
xcrun simctl get_app_container booted com.example.aiscan data

# Database is in: Library/Application Support/aiscan.db
```

### Step 4: Pull the Database File

**Android:**
```bash
# Pull the database file to local directory for inspection
adb shell "run-as com.example.aiscan cat /data/data/com.example.aiscan/databases/aiscan.db" > /tmp/aiscan.db

# Or use adb pull (may require root)
adb pull /data/data/com.example.aiscan/databases/aiscan.db /tmp/aiscan.db
```

### Step 5: Attempt to Open with sqlite3 (Should FAIL)

```bash
# Try to open the database without password - should show garbage or fail
sqlite3 /tmp/aiscan.db ".tables"

# Expected result: Either error or garbage output
# This confirms the database is encrypted
```

**What to expect:**
- Error message like "file is encrypted or is not a database"
- OR: Garbage/corrupted table names with non-printable characters
- OR: Empty result (no tables found)

**This failure is GOOD** - it proves the database is encrypted!

### Step 6: Verify Data is Accessible from the App

1. Keep the app running or restart it
2. Verify all your test documents are visible
3. Test the following operations:
   - Open and view documents
   - Search for documents using the search bar
   - Edit document titles and descriptions
   - Move documents between folders
   - Add/remove tags
   - Delete a document

**Expected result:** All operations should work normally, proving the app can decrypt and access the database.

### Step 7: Verify Encryption Key Source

The database encryption key should come from SecureStorageService:

```bash
# Check the implementation in database_helper.dart
grep -A 5 "password:" lib/core/storage/database_helper.dart
```

Expected: The password parameter should use `_secureStorage.getOrCreateEncryptionKey()`

### Step 8: Check for Backup Files (Post-Migration)

After a successful migration, backup files should be deleted:

```bash
# Check for backup files
adb shell "run-as com.example.aiscan ls -la /data/data/com.example.aiscan/databases/" | grep backup
```

Expected: No `.backup` files should exist after successful migration.

## Success Criteria

- ✅ Database file cannot be read with sqlite3 without password
- ✅ Database file shows encrypted/garbage content when opened without password
- ✅ App can read and write data normally
- ✅ All CRUD operations work correctly
- ✅ Search functionality works
- ✅ Encryption key comes from SecureStorageService
- ✅ No backup files remain after migration

## Troubleshooting

### If the database is readable without password:
1. Check that sqflite_sqlcipher is being used (not regular sqflite)
2. Verify the password parameter is set in openDatabase call
3. Ensure the encryption key is not empty or null

### If the app cannot access data:
1. Check logs for encryption key retrieval errors
2. Verify SecureStorageService is working correctly
3. Check migration logs for errors

### If migration fails:
1. Check migration logs in debug output
2. Verify backup was created
3. Confirm rollback occurred (old database restored)

## Additional Notes

- The same encryption key is used for both file encryption and database encryption
- SQLCipher uses AES-256 encryption
- The encryption is transparent to the app - no code changes needed after setup
- FTS5/FTS4 full-text search works normally with encrypted databases

## Verification Completed

Date: _________________
Tester: _________________
Results: _________________
Notes: _________________
