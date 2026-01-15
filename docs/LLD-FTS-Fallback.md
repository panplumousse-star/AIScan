# Low-Level Design: FTS5/FTS4 Fallback Implementation

## 1. Contexte

### 1.1 Problème identifié
L'application AIScan échoue lors de la sauvegarde des documents scannés avec l'erreur :
```
DatabaseException(no such module: fts5 (code 1 SQLITE_ERROR))
```

### 1.2 Cause racine
Le module SQLite **FTS5** (Full-Text Search 5) n'est pas disponible sur tous les appareils Android. La version de SQLite embarquée varie selon :
- La version d'Android
- Le fabricant de l'appareil
- Les customisations OEM

### 1.3 Impact
- L'initialisation de la base de données échoue
- Le `DocumentRepository` ne peut pas s'initialiser
- Aucun document ne peut être sauvegardé

---

## 2. Solution proposée

### 2.1 Stratégie de fallback

```
┌─────────────────────────────────────────────────────────────┐
│                    Initialisation DB                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │   Essayer FTS5        │
                │   (meilleure perf)    │
                └───────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
         ✓ Succès                    ✗ Échec
              │                           │
              ▼                           ▼
    ┌─────────────────┐       ┌───────────────────────┐
    │ _ftsVersion = 5 │       │   Essayer FTS4        │
    │ Créer triggers  │       │   (compatible)        │
    └─────────────────┘       └───────────────────────┘
                                          │
                            ┌─────────────┴─────────────┐
                            │                           │
                       ✓ Succès                    ✗ Échec
                            │                           │
                            ▼                           ▼
                  ┌─────────────────┐       ┌─────────────────┐
                  │ _ftsVersion = 4 │       │ _ftsVersion = 0 │
                  │ Créer triggers  │       │ FTS désactivé   │
                  └─────────────────┘       │ Log warning     │
                                            └─────────────────┘
```

### 2.2 Compatibilité

| FTS Version | Support Android | Performance | Fonctionnalités |
|-------------|-----------------|-------------|-----------------|
| FTS5        | 5.0+ (variable) | Excellente  | rank(), BM25    |
| FTS4        | 3.0+ (universel)| Bonne       | matchinfo()     |
| Désactivé   | Tous            | N/A         | Recherche basique par LIKE |

---

## 3. Modifications techniques

### 3.1 Fichier: `lib/core/storage/database_helper.dart`

#### 3.1.1 Nouvelles propriétés

```dart
class DatabaseHelper {
  // ... existing code ...

  /// The FTS version being used (5, 4, or 0 if disabled).
  int _ftsVersion = 0;

  /// Whether full-text search is available.
  bool get isFtsAvailable => _ftsVersion > 0;

  /// Returns the FTS version string for SQL queries.
  String get _ftsModule => _ftsVersion == 5 ? 'fts5' : 'fts4';
```

#### 3.1.2 Nouvelle méthode: `_createFtsTable()`

```dart
/// Attempts to create FTS table with fallback strategy.
///
/// Tries FTS5 first, then FTS4, then disables FTS if both fail.
/// Returns true if FTS was successfully created.
Future<bool> _createFtsTable(Database db) async {
  // Try FTS5 first
  if (await _tryCreateFts5(db)) {
    _ftsVersion = 5;
    return true;
  }

  // Fallback to FTS4
  if (await _tryCreateFts4(db)) {
    _ftsVersion = 4;
    return true;
  }

  // FTS not available
  _ftsVersion = 0;
  debugPrint('WARNING: Full-text search is not available on this device');
  return false;
}
```

#### 3.1.3 Méthode: `_tryCreateFts5()`

```dart
/// Attempts to create FTS5 virtual table.
Future<bool> _tryCreateFts5(Database db) async {
  try {
    await db.execute('''
      CREATE VIRTUAL TABLE $tableDocumentsFts USING fts5(
        title,
        description,
        ocr_text,
        content=$tableDocuments,
        content_rowid=rowid
      )
    ''');
    return true;
  } catch (e) {
    debugPrint('FTS5 not available: $e');
    return false;
  }
}
```

#### 3.1.4 Méthode: `_tryCreateFts4()`

```dart
/// Attempts to create FTS4 virtual table as fallback.
Future<bool> _tryCreateFts4(Database db) async {
  try {
    await db.execute('''
      CREATE VIRTUAL TABLE $tableDocumentsFts USING fts4(
        title,
        description,
        ocr_text,
        content=$tableDocuments
      )
    ''');
    return true;
  } catch (e) {
    debugPrint('FTS4 not available: $e');
    return false;
  }
}
```

#### 3.1.5 Méthode: `_createFtsTriggers()`

```dart
/// Creates triggers to keep FTS index synchronized.
/// Only called if FTS is available.
Future<void> _createFtsTriggers(Database db) async {
  if (_ftsVersion == 5) {
    await _createFts5Triggers(db);
  } else if (_ftsVersion == 4) {
    await _createFts4Triggers(db);
  }
}

Future<void> _createFts5Triggers(Database db) async {
  // INSERT trigger
  await db.execute('''
    CREATE TRIGGER documents_ai AFTER INSERT ON $tableDocuments BEGIN
      INSERT INTO $tableDocumentsFts(rowid, title, description, ocr_text)
      VALUES (NEW.rowid, NEW.$columnTitle, NEW.$columnDescription, NEW.$columnOcrText);
    END
  ''');

  // DELETE trigger
  await db.execute('''
    CREATE TRIGGER documents_ad AFTER DELETE ON $tableDocuments BEGIN
      INSERT INTO $tableDocumentsFts($tableDocumentsFts, rowid, title, description, ocr_text)
      VALUES ('delete', OLD.rowid, OLD.$columnTitle, OLD.$columnDescription, OLD.$columnOcrText);
    END
  ''');

  // UPDATE trigger
  await db.execute('''
    CREATE TRIGGER documents_au AFTER UPDATE ON $tableDocuments BEGIN
      INSERT INTO $tableDocumentsFts($tableDocumentsFts, rowid, title, description, ocr_text)
      VALUES ('delete', OLD.rowid, OLD.$columnTitle, OLD.$columnDescription, OLD.$columnOcrText);
      INSERT INTO $tableDocumentsFts(rowid, title, description, ocr_text)
      VALUES (NEW.rowid, NEW.$columnTitle, NEW.$columnDescription, NEW.$columnOcrText);
    END
  ''');
}

Future<void> _createFts4Triggers(Database db) async {
  // INSERT trigger
  await db.execute('''
    CREATE TRIGGER documents_ai AFTER INSERT ON $tableDocuments BEGIN
      INSERT INTO $tableDocumentsFts(docid, title, description, ocr_text)
      VALUES (NEW.rowid, NEW.$columnTitle, NEW.$columnDescription, NEW.$columnOcrText);
    END
  ''');

  // DELETE trigger
  await db.execute('''
    CREATE TRIGGER documents_ad AFTER DELETE ON $tableDocuments BEGIN
      DELETE FROM $tableDocumentsFts WHERE docid = OLD.rowid;
    END
  ''');

  // UPDATE trigger
  await db.execute('''
    CREATE TRIGGER documents_au AFTER UPDATE ON $tableDocuments BEGIN
      DELETE FROM $tableDocumentsFts WHERE docid = OLD.rowid;
      INSERT INTO $tableDocumentsFts(docid, title, description, ocr_text)
      VALUES (NEW.rowid, NEW.$columnTitle, NEW.$columnDescription, NEW.$columnOcrText);
    END
  ''');
}
```

#### 3.1.6 Modification de `_onCreate()`

```dart
Future<void> _onCreate(Database db, int version) async {
  try {
    // Create folders table
    await db.execute('''...''');

    // Create documents table
    await db.execute('''...''');

    // Create tags table
    await db.execute('''...''');

    // Create document_tags junction table
    await db.execute('''...''');

    // Create signatures table
    await db.execute('''...''');

    // Create FTS table with fallback (NEW)
    final ftsCreated = await _createFtsTable(db);

    // Create FTS triggers only if FTS is available (NEW)
    if (ftsCreated) {
      await _createFtsTriggers(db);
    }

    // Create indices for common queries
    await db.execute('''...''');
    // ... other indices ...

  } catch (e) {
    throw DatabaseException('Failed to create database schema', cause: e);
  }
}
```

#### 3.1.7 Modification de `searchDocuments()`

```dart
/// Performs a full-text search across document content.
///
/// If FTS is not available, falls back to LIKE-based search.
Future<List<String>> searchDocuments(String query) async {
  if (query.trim().isEmpty) {
    return [];
  }

  try {
    final db = await database;

    // Use FTS if available
    if (isFtsAvailable) {
      return await _searchWithFts(db, query);
    }

    // Fallback to LIKE-based search
    return await _searchWithLike(db, query);
  } catch (e) {
    throw DatabaseException('Failed to search documents', cause: e);
  }
}

Future<List<String>> _searchWithFts(Database db, String query) async {
  final escapedQuery = _escapeFtsQuery(query);

  String sql;
  if (_ftsVersion == 5) {
    // FTS5 uses rank for ordering
    sql = '''
      SELECT d.$columnId
      FROM $tableDocuments d
      INNER JOIN $tableDocumentsFts fts ON d.rowid = fts.rowid
      WHERE $tableDocumentsFts MATCH ?
      ORDER BY fts.rank
    ''';
  } else {
    // FTS4 doesn't have built-in rank
    sql = '''
      SELECT d.$columnId
      FROM $tableDocuments d
      INNER JOIN $tableDocumentsFts fts ON d.rowid = fts.docid
      WHERE $tableDocumentsFts MATCH ?
      ORDER BY d.$columnCreatedAt DESC
    ''';
  }

  final results = await db.rawQuery(sql, [escapedQuery]);
  return results.map((row) => row[columnId] as String).toList();
}

Future<List<String>> _searchWithLike(Database db, String query) async {
  final likeQuery = '%${query.trim()}%';

  final results = await db.rawQuery('''
    SELECT $columnId FROM $tableDocuments
    WHERE $columnTitle LIKE ?
       OR $columnDescription LIKE ?
       OR $columnOcrText LIKE ?
    ORDER BY $columnCreatedAt DESC
  ''', [likeQuery, likeQuery, likeQuery]);

  return results.map((row) => row[columnId] as String).toList();
}
```

#### 3.1.8 Modification de `rebuildFtsIndex()`

```dart
/// Rebuilds the FTS index.
///
/// Does nothing if FTS is not available.
Future<void> rebuildFtsIndex() async {
  if (!isFtsAvailable) {
    debugPrint('FTS not available, skipping index rebuild');
    return;
  }

  try {
    final db = await database;

    if (_ftsVersion == 5) {
      await db.execute(
        "INSERT INTO $tableDocumentsFts($tableDocumentsFts) VALUES('rebuild')",
      );
    } else {
      // FTS4 rebuild syntax
      await db.execute(
        "INSERT INTO $tableDocumentsFts($tableDocumentsFts) VALUES('rebuild')",
      );
    }
  } catch (e) {
    throw DatabaseException('Failed to rebuild FTS index', cause: e);
  }
}
```

---

## 4. Gestion de la migration

### 4.1 Nouvelle version de schéma

```dart
static const int _databaseVersion = 2; // Increment from 1
```

### 4.2 Méthode `_onUpgrade()`

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Migration v1 -> v2: FTS fallback support
    // Try to detect current FTS state
    try {
      await db.rawQuery('SELECT * FROM $tableDocumentsFts LIMIT 1');
      // FTS exists, check if it's FTS5 or FTS4
      _ftsVersion = await _detectFtsVersion(db);
    } catch (e) {
      // FTS doesn't exist or is broken, try to recreate
      await _dropFtsIfExists(db);
      await _createFtsTable(db);
      if (isFtsAvailable) {
        await _createFtsTriggers(db);
        await _populateFtsFromDocuments(db);
      }
    }
  }
}

Future<int> _detectFtsVersion(Database db) async {
  try {
    // FTS5 specific: try to use rank
    await db.rawQuery(
      'SELECT rank FROM $tableDocumentsFts LIMIT 1'
    );
    return 5;
  } catch (e) {
    return 4;
  }
}

Future<void> _dropFtsIfExists(Database db) async {
  try {
    await db.execute('DROP TRIGGER IF EXISTS documents_ai');
    await db.execute('DROP TRIGGER IF EXISTS documents_ad');
    await db.execute('DROP TRIGGER IF EXISTS documents_au');
    await db.execute('DROP TABLE IF EXISTS $tableDocumentsFts');
  } catch (_) {}
}

Future<void> _populateFtsFromDocuments(Database db) async {
  if (_ftsVersion == 5) {
    await db.execute('''
      INSERT INTO $tableDocumentsFts(rowid, title, description, ocr_text)
      SELECT rowid, $columnTitle, $columnDescription, $columnOcrText
      FROM $tableDocuments
    ''');
  } else if (_ftsVersion == 4) {
    await db.execute('''
      INSERT INTO $tableDocumentsFts(docid, title, description, ocr_text)
      SELECT rowid, $columnTitle, $columnDescription, $columnOcrText
      FROM $tableDocuments
    ''');
  }
}
```

---

## 5. Tests

### 5.1 Tests unitaires

```dart
group('FTS Fallback', () {
  test('should use FTS5 when available', () async {
    // Mock database with FTS5 support
    final db = DatabaseHelper();
    await db.initialize();

    expect(db.isFtsAvailable, isTrue);
    expect(db._ftsVersion, equals(5));
  });

  test('should fallback to FTS4 when FTS5 unavailable', () async {
    // Mock database without FTS5
    // ...
  });

  test('should work without FTS', () async {
    // Mock database without FTS support
    final db = DatabaseHelper();
    await db.initialize();

    // Should not throw
    final results = await db.searchDocuments('test');
    expect(results, isA<List<String>>());
  });

  test('search should work with LIKE fallback', () async {
    // Insert test document
    // Search without FTS
    // Verify results
  });
});
```

### 5.2 Tests d'intégration

1. Tester sur émulateur Android 5.0 (API 21)
2. Tester sur émulateur Android 10 (API 29)
3. Tester sur appareil physique Xiaomi (cas original)

---

## 6. Logging et monitoring

### 6.1 Logs à ajouter

```dart
// Au démarrage
debugPrint('Database initialized with FTS version: $_ftsVersion');

// Si FTS échoue
debugPrint('WARNING: FTS5 not available, trying FTS4...');
debugPrint('WARNING: FTS4 not available, full-text search disabled');

// Lors des recherches
if (!isFtsAvailable) {
  debugPrint('Using LIKE-based search (FTS not available)');
}
```

### 6.2 Métriques à collecter (optionnel)

- `fts_version`: Version FTS utilisée (5, 4, 0)
- `search_latency_ms`: Temps de recherche
- `search_fallback_used`: Boolean si LIKE utilisé

---

## 7. Risques et mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| FTS4 également indisponible | Faible | Moyen | Fallback LIKE implémenté |
| Performance LIKE dégradée | Moyen | Faible | Acceptable pour petites collections |
| Migration échoue | Faible | Élevé | Catch + recréation FTS |
| Triggers incompatibles | Faible | Moyen | Syntaxe différenciée FTS4/FTS5 |

---

## 8. Checklist d'implémentation

- [ ] Ajouter propriété `_ftsVersion`
- [ ] Ajouter getter `isFtsAvailable`
- [ ] Créer méthode `_createFtsTable()`
- [ ] Créer méthode `_tryCreateFts5()`
- [ ] Créer méthode `_tryCreateFts4()`
- [ ] Créer méthode `_createFtsTriggers()`
- [ ] Créer méthode `_createFts5Triggers()`
- [ ] Créer méthode `_createFts4Triggers()`
- [ ] Modifier `_onCreate()` pour utiliser fallback
- [ ] Créer méthode `_searchWithFts()`
- [ ] Créer méthode `_searchWithLike()`
- [ ] Modifier `searchDocuments()` pour utiliser fallback
- [ ] Modifier `rebuildFtsIndex()` pour gérer absence FTS
- [ ] Incrémenter `_databaseVersion` à 2
- [ ] Implémenter `_onUpgrade()` pour migration
- [ ] Ajouter logs de diagnostic
- [ ] Écrire tests unitaires
- [ ] Tester sur appareil réel

---

## 9. Estimation

| Tâche | Temps estimé |
|-------|--------------|
| Implémentation fallback FTS | 1h |
| Modification searchDocuments | 30min |
| Migration et upgrade | 30min |
| Tests | 1h |
| **Total** | **3h** |

---

## 10. Approbation

| Rôle | Nom | Date | Signature |
|------|-----|------|-----------|
| Développeur | | | |
| Reviewer | | | |
