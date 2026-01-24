# Prompt : Suppression Feature "OCR Contact Extraction"

## Contexte

L'application AIscan possède une fonctionnalité d'extraction de contacts depuis les documents scannés via OCR. Cette feature utilise les permissions `READ_CONTACTS` et `WRITE_CONTACTS` qui nécessitent une justification forte pour le Google Play Store.

**Décision** : Supprimer la création automatique de contacts. L'utilisateur gérera lui-même l'ajout de contacts manuellement.

**Important** : L'OCR est CONSERVÉ. L'utilisateur pourra toujours extraire le texte et le copier manuellement.

---

## Fichiers à SUPPRIMER (5 fichiers)

### 1. Dossier `lib/features/contacts/` (COMPLET)

```
lib/features/contacts/
├── domain/
│   ├── contact_data_extractor.dart    # ~424 lignes - Regex extraction contacts
│   └── contact_service.dart           # ~310 lignes - Flutter Contacts API
└── presentation/
    └── contact_creation_sheet.dart    # ~468 lignes - Bottom sheet création contact
```

**Action** : `rm -rf lib/features/contacts/`

### 2. Services de permission contacts

```
lib/core/permissions/contact_permission_service.dart   # ~262 lignes
lib/core/permissions/contact_permission_dialog.dart    # ~143 lignes
```

**Action** : Supprimer ces 2 fichiers

---

## Fichiers à MODIFIER (3 fichiers)

### 1. `android/app/src/main/AndroidManifest.xml`

**Supprimer les lignes** :
```xml
<!-- Contacts permissions for OCR contact extraction -->
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.WRITE_CONTACTS" />
```

---

### 2. `pubspec.yaml`

**Supprimer la dépendance** :
```yaml
flutter_contacts: ^1.1.9+2   # ou version similaire
```

---

### 3. `lib/features/scanner/presentation/helpers/scanner_action_handler.dart`

**Modifier la méthode `handleOcr()` pour afficher le texte OCR sans création de contact.**

#### Imports à SUPPRIMER (lignes 14, 16, 17) :
```dart
// SUPPRIMER ces imports :
import '../../../../core/permissions/contact_permission_dialog.dart';
import '../../../contacts/presentation/contact_creation_sheet.dart';
import '../../../contacts/domain/contact_data_extractor.dart';
```

#### Nouvelle implémentation de `handleOcr()` :

Remplacer la méthode actuelle (lignes 160-244) par :

```dart
/// Handles OCR processing on the scanned document.
/// Extracts text and shows it in a dialog for the user to copy.
Future<void> handleOcr(ScannerScreenState state) async {
  if (state.scanResult == null || state.scanResult!.pages.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pages to process'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  // Show loading indicator
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('Extracting text...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );
  }

  try {
    final ocrService = ref.read(ocrServiceProvider);

    // Run OCR on all scanned pages
    final textParts = <String>[];
    for (final page in state.scanResult!.pages) {
      final imageFile = File(page.imagePath);
      if (await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();
        final result = await ocrService.extractTextFromBytes(imageBytes);
        if (result.text.isNotEmpty) {
          textParts.add(result.text);
        }
      }
    }

    // Hide loading snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (!context.mounted) return;

    if (textParts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No text found in document'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Combine all text
    final combinedText = textParts.join('\n\n');

    // Show OCR result dialog with copy option
    await _showOcrResultDialog(context, combinedText);

  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }
}

/// Shows the OCR result in a dialog with copy functionality.
Future<void> _showOcrResultDialog(BuildContext context, String text) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.text_snippet_outlined,
               color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Extracted Text'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: SingleChildScrollView(
          child: SelectableText(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Text copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy All'),
        ),
      ],
    ),
  );
}
```

#### Import à AJOUTER :
```dart
import 'package:flutter/services.dart';  // Pour Clipboard
```

---

## Vérifications post-suppression

### 1. Rechercher les références orphelines

```bash
# Vérifier qu'aucun import ne pointe vers contacts
grep -r "import.*contacts" lib/
grep -r "ContactData" lib/
grep -r "ContactService" lib/
grep -r "ContactPermission" lib/
grep -r "showContactCreationSheet" lib/
grep -r "showNoContactDataFoundSnackbar" lib/
grep -r "flutter_contacts" .
```

### 2. Vérifier permission_exception.dart

Le fichier `lib/core/permissions/permission_exception.dart` est-il encore utilisé par d'autres services ?

```bash
grep -r "PermissionException" lib/ --include="*.dart" | grep -v "permission_exception.dart"
```

- Si utilisé ailleurs : le garder
- Si non utilisé : le supprimer aussi

### 3. Nettoyer et vérifier

```bash
flutter pub get
flutter analyze
flutter build apk --debug
```

---

## Résumé des actions

| Action | Fichier/Dossier | Détail |
|--------|-----------------|--------|
| `rm -rf` | `lib/features/contacts/` | Suppression dossier complet |
| `rm` | `lib/core/permissions/contact_permission_service.dart` | Suppression |
| `rm` | `lib/core/permissions/contact_permission_dialog.dart` | Suppression |
| `edit` | `android/app/src/main/AndroidManifest.xml` | Supprimer READ/WRITE_CONTACTS |
| `edit` | `pubspec.yaml` | Supprimer flutter_contacts |
| `edit` | `scanner_action_handler.dart` | Remplacer handleOcr() par version simple |

---

## Nouvelle UX après modification

| Avant | Après |
|-------|-------|
| OCR → Extraction contacts → Bottom sheet création | OCR → Dialog avec texte → Bouton "Copy All" |
| Permissions contacts requises | Aucune permission contact |
| Création automatique de contact | L'utilisateur copie et crée manuellement |

---

## Impact sur la roadmap Play Store

| Item | Avant | Après |
|------|-------|-------|
| Permissions sensibles | `READ_CONTACTS`, `WRITE_CONTACTS` | **Aucune** |
| Justification Data Safety | Requise pour contacts | **Non requise** |
| Risque rejet Play Store | Moyen (permissions sensibles) | **Faible** |
| Dépendances tierces | flutter_contacts | **Supprimée** |
| Section 1.3 roadmap | ⚠️ 2 permissions à justifier | ✅ Résolu |

---

## Checklist d'exécution

- [ ] Supprimer `lib/features/contacts/` (3 fichiers)
- [ ] Supprimer `lib/core/permissions/contact_permission_service.dart`
- [ ] Supprimer `lib/core/permissions/contact_permission_dialog.dart`
- [ ] Modifier `AndroidManifest.xml` (supprimer 2 permissions)
- [ ] Modifier `pubspec.yaml` (supprimer flutter_contacts)
- [ ] Modifier `scanner_action_handler.dart` (nouvelle implémentation handleOcr)
- [ ] Ajouter import `flutter/services.dart` pour Clipboard
- [ ] Vérifier `permission_exception.dart` (garder ou supprimer)
- [ ] `flutter pub get`
- [ ] `flutter analyze` (0 erreurs)
- [ ] Test build debug
- [ ] Test fonctionnel OCR → copie texte
