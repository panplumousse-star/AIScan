// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Scanai';

  @override
  String get settings => 'Einstellungen';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeAuto => 'Automatisch';

  @override
  String get security => 'Sperre';

  @override
  String get enabled => 'Aktiviert';

  @override
  String get disabled => 'Deaktiviert';

  @override
  String get enableLockTitle => 'Sperre aktivieren?';

  @override
  String get enableLockMessage =>
      'Möchten Sie den Zugang zu Ihren Dokumenten mit Ihrem Fingerabdruck sichern?';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get enable => 'Aktivieren';

  @override
  String get lockTimeoutImmediate => 'Sofort';

  @override
  String get lockTimeout1Min => '1 Min';

  @override
  String get lockTimeout5Min => '5 Min';

  @override
  String get lockTimeout30Min => '30 Min';

  @override
  String get about => 'Über';

  @override
  String get developedWith => 'Entwickelt mit';

  @override
  String get securityDetails => 'Sicherheitsdetails';

  @override
  String get securityTitle => 'Sicherheit';

  @override
  String get aes256 => 'AES-256';

  @override
  String get localEncryption => 'Lokale Verschlüsselung';

  @override
  String get zeroKnowledge => 'Zero-Knowledge';

  @override
  String get exclusiveAccess => 'Exklusiver Zugang';

  @override
  String get offline => 'Offline';

  @override
  String get securedPercent => '100% gesichert';

  @override
  String get settingsSpeechBubbleLine1 => 'Eine kleine';

  @override
  String get settingsSpeechBubbleLine2 => 'Anpassung?';

  @override
  String get dismiss => 'Schließen';

  @override
  String get myDocuments => 'Meine Dokumente';

  @override
  String get scan => 'Scannen';

  @override
  String get share => 'Teilen';

  @override
  String get delete => 'Löschen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get noDocuments => 'Keine Dokumente';

  @override
  String get scanYourFirstDocument => 'Scannen Sie Ihr erstes Dokument';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dokumente',
      one: '1 Dokument',
      zero: 'Keine Dokumente',
    );
    return '$_temp0';
  }

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Seiten',
      one: '1 Seite',
    );
    return '$_temp0';
  }

  @override
  String get greetingMorning => 'Guten Morgen';

  @override
  String get greetingAfternoon => 'Guten Tag';

  @override
  String get greetingEvening => 'Guten Abend';

  @override
  String get randomMessage1 => 'PDF benötigt?';

  @override
  String get randomMessage2 => 'Los geht\'s?';

  @override
  String get randomMessage3 => 'Warte auf Ihre Befehle!';

  @override
  String get randomMessage4 => 'Auf geht\'s!';

  @override
  String get ocrResults => 'OCR-Ergebnisse';

  @override
  String get text => 'Text';

  @override
  String get metadata => 'Metadaten';

  @override
  String get copyText => 'Kopieren';

  @override
  String get textCopied => 'Text kopiert';

  @override
  String get noTextExtracted => 'Kein Text extrahiert';

  @override
  String get language => 'Sprache';

  @override
  String get processingTime => 'Verarbeitungszeit';

  @override
  String get wordCount => 'Wortanzahl';

  @override
  String get lineCount => 'Zeilenanzahl';

  @override
  String get confidence => 'Konfidenz';

  @override
  String get shareAs => 'Teilen als';

  @override
  String get pdf => 'PDF';

  @override
  String get images => 'Bilder';

  @override
  String get ocrText => 'OCR-Text';

  @override
  String get appLanguage => 'App-Sprache';

  @override
  String get ocrLanguage => 'OCR-Sprache';

  @override
  String get systemLanguage => 'System';

  @override
  String get french => 'Französisch';

  @override
  String get english => 'Englisch';

  @override
  String get ocrLanguageAuto => 'Automatisch';

  @override
  String get ocrLanguageLatin => 'Latein (EN, FR, ES...)';

  @override
  String get ocrLanguageChinese => 'Chinesisch';

  @override
  String get ocrLanguageJapanese => 'Japanisch';

  @override
  String get ocrLanguageKorean => 'Koreanisch';

  @override
  String get ocrLanguageDevanagari => 'Devanagari';

  @override
  String get scanDocument => 'Dokument\nscannen';

  @override
  String get camera => 'Kamera';

  @override
  String get gallery => 'Galerie';

  @override
  String get recentScans => 'Letzte Scans';

  @override
  String get allDocuments => 'Meine Dateien anzeigen';

  @override
  String get searchDocuments => 'Dokumente suchen';

  @override
  String get sortByDate => 'Nach Datum sortieren';

  @override
  String get sortByName => 'Nach Name sortieren';

  @override
  String get deleteConfirmTitle => 'Dokument löschen?';

  @override
  String get deleteConfirmMessage =>
      'Diese Aktion kann nicht rückgängig gemacht werden. Das Dokument wird dauerhaft gelöscht.';

  @override
  String get errorOccurred => 'Ein Fehler ist aufgetreten';

  @override
  String get retry => 'Wiederholen';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Ja';

  @override
  String get no => 'Nein';

  @override
  String get save => 'Speichern';

  @override
  String get close => 'Schließen';

  @override
  String get extractText => 'Text extrahieren';

  @override
  String get extractingText => 'Text wird extrahiert...';

  @override
  String get documentName => 'Dokumentname';

  @override
  String get enterDocumentName => 'Dokumentname eingeben';

  @override
  String get createdAt => 'Erstellt';

  @override
  String get modifiedAt => 'Geändert';

  @override
  String get size => 'Größe';

  @override
  String get selectLanguage => 'Sprache auswählen';

  @override
  String get languageSettings => 'Spracheinstellungen';

  @override
  String get openingScanner => 'Scanner wird geöffnet...';

  @override
  String get savingDocument => 'Dokument wird gespeichert...';

  @override
  String get launchingScanner => 'Scanner wird gestartet...';

  @override
  String documentExportedTo(String folder) {
    return 'Dokument exportiert nach $folder';
  }

  @override
  String get abandonScanTitle => 'Scan abbrechen?';

  @override
  String get abandonScanMessage =>
      'Sind Sie sicher, dass Sie diesen Scan abbrechen möchten? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get abandon => 'Abbrechen';

  @override
  String get scanSuccessMessage => 'Fertig, es ist gespeichert!';

  @override
  String get savePromptMessage => 'Sollen wir es speichern?';

  @override
  String get searchFolder => 'Ordner suchen...';

  @override
  String get newFolder => 'Neu';

  @override
  String get folderCreationFailed => 'Ordner konnte nicht erstellt werden';

  @override
  String get myDocs => 'Meine Docs';

  @override
  String get saveHere => 'Hier speichern';

  @override
  String get export => 'Exportieren';

  @override
  String get ocr => 'OCR';

  @override
  String get finish => 'Fertig';

  @override
  String get move => 'Verschieben';

  @override
  String get decrypting => 'Entschlüsseln...';

  @override
  String get loading => 'Laden...';

  @override
  String get unableToLoadImage => 'Bild kann nicht geladen werden';

  @override
  String get noTextDetected => 'Kein Text im Dokument erkannt';

  @override
  String get noTextToShare => 'Kein Text zum Teilen';

  @override
  String get shareError => 'Fehler beim Teilen';

  @override
  String get folderCreationError => 'Fehler beim Erstellen des Ordners';

  @override
  String get favoriteUpdateFailed =>
      'Favoriten konnten nicht aktualisiert werden';

  @override
  String get documentExported => 'Dokument exportiert';

  @override
  String documentsExported(int count) {
    return '$count Dokumente exportiert';
  }

  @override
  String get title => 'Titel';

  @override
  String get pages => 'Seiten';

  @override
  String get format => 'Format';

  @override
  String get justNow => 'Gerade eben';

  @override
  String minutesAgo(int minutes) {
    return 'Vor $minutes Min';
  }

  @override
  String hoursAgo(int hours) {
    return 'Vor $hours Std';
  }

  @override
  String daysAgo(int days) {
    return 'Vor $days Tagen';
  }

  @override
  String get lastUpdated => 'Zuletzt aktualisiert';

  @override
  String folderSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ordner ausgewählt',
      one: '1 Ordner ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String documentSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Dokumente ausgewählt',
      one: '1 Dokument ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get currentFolder => 'Aktueller Ordner';

  @override
  String noResultsFor(String query) {
    return 'Keine Ergebnisse für \"$query\"';
  }

  @override
  String get noFavorites => 'Keine Favoriten';

  @override
  String get copy => 'Kopieren';

  @override
  String get selectAll => 'Alle auswählen';

  @override
  String get selectionModeActive => 'Auswahlmodus aktiv';

  @override
  String get longPressToSelect => 'Lang drücken zum Auswählen';

  @override
  String get selectTextEasily => 'Text einfach auswählen';

  @override
  String get selection => 'Auswahl';

  @override
  String wordSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wörter ausgewählt',
      one: '1 Wort ausgewählt',
    );
    return '$_temp0';
  }

  @override
  String get renameDocument => 'Dokument umbenennen';

  @override
  String get newTitle => 'Neuer Titel...';

  @override
  String get saveUnder => 'Speichern unter...';

  @override
  String moveDocuments(int count) {
    return '$count Dokumente verschieben';
  }

  @override
  String get chooseDestinationFolder => 'Wählen Sie einen Zielordner';

  @override
  String get rootFolder => 'Stammordner (kein Ordner)';

  @override
  String get createNewFolder => 'Neuen Ordner erstellen';

  @override
  String get singleDocumentCompressed => 'Einzelnes komprimiertes Dokument';

  @override
  String get originalQualityPng => 'Originalqualität (PNG)';

  @override
  String get pleaseWait => 'Bitte warten...';

  @override
  String get somethingWentWrong => 'Hoppla! Etwas ist schiefgelaufen';

  @override
  String get editFolder => 'Ordner bearbeiten';

  @override
  String get folderName => 'Ordnername...';

  @override
  String get create => 'Erstellen';

  @override
  String get nameCannotBeEmpty => 'Name darf nicht leer sein';

  @override
  String get createFolderToOrganize =>
      'Erstellen Sie einen Ordner, um Ihre Dokumente zu organisieren';

  @override
  String get createFolder => 'Ordner erstellen';

  @override
  String get appIsLocked => 'Scanai ist gesperrt';

  @override
  String get authenticateToAccess =>
      'Authentifizieren Sie sich, um auf Ihre gesicherten Dokumente zuzugreifen.';

  @override
  String get unlock => 'Entsperren';

  @override
  String get preparingImage => 'Bild wird vorbereitet...';

  @override
  String get celebrationMessage1 => 'Einfach!';

  @override
  String get celebrationMessage2 => 'Nochmal?!';

  @override
  String get celebrationMessage3 => 'Brauchen Sie mich nochmal?';

  @override
  String get celebrationMessage4 => 'Noch einer erledigt!';

  @override
  String get celebrationMessage5 => 'Arbeit erledigt!';

  @override
  String get celebrationMessage6 => 'Weiter!';

  @override
  String get shareAppText =>
      'Ich verwende Scanai, um meine wichtigen Dokumente zu sichern und zu organisieren. Es ist schnell, sicher und reibungslos!';

  @override
  String get shareAppSubject => 'Scanai: Ihr sicherer Taschenscanner';

  @override
  String get secureYourDocuments => 'Sichern Sie Ihre Dokumente';

  @override
  String get savedLocally => 'Alles lokal gespeichert';

  @override
  String documentsSecured(int count) {
    return '$count Dokumente gesichert';
  }

  @override
  String get preferences => 'Einstellungen';

  @override
  String get interface => 'Oberfläche';

  @override
  String get textRecognition => 'Texterkennung';

  @override
  String get search => 'Suchen...';

  @override
  String nDocumentsLabel(int count) {
    return '$count Dokumente';
  }

  @override
  String nFoldersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Ordner',
      one: '1 Ordner',
    );
    return '$_temp0';
  }

  @override
  String nDocs(int count) {
    return '$count Docs';
  }

  @override
  String foldersAndDocs(int folders, int documents) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders Ordner',
      one: '1 Ordner',
    );
    String _temp1 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents Dokumente',
      one: '1 Dokument',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get scanner => 'Scannen';

  @override
  String get sortAndFilter => 'Sortieren & Filtern';

  @override
  String get clearAll => 'Alle löschen';

  @override
  String get sortBy => 'Sortieren nach';

  @override
  String get quickFilters => 'Schnellfilter';

  @override
  String get folder => 'Ordner';

  @override
  String get tags => 'Tags';

  @override
  String get apply => 'Anwenden';

  @override
  String get favoritesOnly => 'Nur Favoriten';

  @override
  String get favoritesOnlyDescription =>
      'Nur als Favorit markierte Dokumente anzeigen';

  @override
  String get hasOcrText => 'Hat OCR-Text';

  @override
  String get hasOcrTextDescription =>
      'Nur Dokumente mit extrahiertem Text anzeigen';

  @override
  String get failedToLoadFolders => 'Ordner konnten nicht geladen werden';

  @override
  String get noFoldersYet => 'Noch keine Ordner erstellt';

  @override
  String get allDocumentsFilter => 'Alle Dokumente';

  @override
  String get failedToLoadTags => 'Tags konnten nicht geladen werden';

  @override
  String get noTagsYet => 'Noch keine Tags erstellt';

  @override
  String get initializingOcr => 'OCR wird initialisiert...';

  @override
  String get ocrSaved => 'OCR-Text im Dokument gespeichert';

  @override
  String copiedWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Wörter',
      one: '1 Wort',
    );
    return '$_temp0 in die Zwischenablage kopiert';
  }

  @override
  String get failedToCopyText =>
      'Text konnte nicht in die Zwischenablage kopiert werden';

  @override
  String get searchInText => 'Im Text suchen...';

  @override
  String matchesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Treffer gefunden',
      one: '1 Treffer gefunden',
    );
    return '$_temp0';
  }

  @override
  String get done => 'Fertig';

  @override
  String get extractingTextProgress => 'Text wird extrahiert...';

  @override
  String processingPage(int current, int total) {
    return 'Seite $current von $total wird verarbeitet';
  }

  @override
  String get thisMayTakeAMoment => 'Dies kann einen Moment dauern';

  @override
  String get scrollDisabledInSelectionMode =>
      'Auswahlmodus aktiv - Scrollen deaktiviert';

  @override
  String get words => 'Wörter';

  @override
  String get lines => 'Zeilen';

  @override
  String get time => 'Zeit';

  @override
  String get noTextFound => 'Kein Text gefunden';

  @override
  String get noTextFoundDescription =>
      'Das Bild enthält möglicherweise keinen lesbaren Text,\noder die Qualität ist zu niedrig.';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get extractTextTitle => 'Text extrahieren';

  @override
  String get extractTextDescription =>
      'OCR ausführen, um lesbaren Text\naus diesem Dokument zu extrahieren.';

  @override
  String get runOcr => 'OCR ausführen';

  @override
  String get allProcessingLocal =>
      'Alle Verarbeitung erfolgt lokal auf Ihrem Gerät';

  @override
  String get ocrOptions => 'OCR-Optionen';

  @override
  String get documentType => 'Dokumenttyp';

  @override
  String get auto => 'Automatisch';

  @override
  String get singleColumn => 'Einzelne Spalte';

  @override
  String get singleBlock => 'Einzelner Block';

  @override
  String get sparseText => 'Verstreuter Text';

  @override
  String get rerunOcr => 'OCR erneut ausführen';

  @override
  String get saveToDocument => 'Im Dokument speichern';

  @override
  String get copySelection => 'Auswahl kopieren';

  @override
  String get copySelectionTooltip =>
      'Ausgewählten Text in die Zwischenablage kopieren';

  @override
  String get searchInTextTooltip => 'Im Text suchen';

  @override
  String get copyAllTextTooltip => 'Gesamten Text kopieren';

  @override
  String get shareTextTooltip => 'Text teilen';

  @override
  String get loadingDocuments => 'Ihre Dokumente werden geladen...';

  @override
  String get exportFailed => 'Export fehlgeschlagen';

  @override
  String get whatAreYouLookingFor => 'Was suchen Sie?';

  @override
  String get needHelp => 'Hilfe benötigt?';

  @override
  String get licenses => 'Open-Source-Lizenzen';

  @override
  String get licensesSubtitle => 'Bibliothekslizenzen anzeigen';

  @override
  String get localStorageWarningTitle => 'Nur lokaler Speicher';

  @override
  String get localStorageWarningMessage =>
      'Ihre Dokumente werden auf Ihrem Gerät gespeichert und verschlüsselt. Wenn Sie die App deinstallieren, werden sie dauerhaft gelöscht.\n\nDenken Sie daran, Ihre wichtigen Dokumente zu exportieren!';

  @override
  String get localStorageWarningButton => 'Verstanden';

  @override
  String get deviceSecurityWarningTitle => 'Sicherheitswarnung';

  @override
  String get deviceSecurityWarningMessage =>
      'Ihr Gerät scheint gerootet oder jailbroken zu sein.';

  @override
  String get deviceSecurityWarningDetails =>
      'Auf modifizierten Geräten können Sicherheitsfunktionen wie Verschlüsselung, sicherer Speicher und biometrische Authentifizierung kompromittiert sein. Ihre Dokumente könnten gefährdet sein.\n\nDie App funktioniert weiterhin, aber bitte beachten Sie die reduzierte Sicherheit.';

  @override
  String get deviceSecurityContinue => 'Ich verstehe';

  @override
  String get showSecurityWarnings => 'Sicherheitswarnungen anzeigen';

  @override
  String get showSecurityWarningsDescription =>
      'Warnungen anzeigen, wenn auf gerooteten oder jailbroken Geräten ausgeführt';

  @override
  String get premiumTitle => 'Premium Lifetime';

  @override
  String get premiumSubtitle =>
      'Alle Funktionen mit einmaligem Kauf freischalten';

  @override
  String get premiumUnlockPotential => 'Schalte mein volles Potenzial frei!';

  @override
  String get premiumNoScansLeft => 'Sie haben keine kostenlosen Scans mehr!';

  @override
  String get premiumOcrRequired => 'OCR ist Premium-Mitgliedern vorbehalten';

  @override
  String get premiumExportRequired =>
      'PDF-Export ist Premium-Mitgliedern vorbehalten';

  @override
  String get premiumFeatureUnlimitedScans => 'Unbegrenzte Scans';

  @override
  String get premiumFeatureMultipage => 'Mehrseitige Dokumente (bis zu 100)';

  @override
  String get premiumFeaturePdfExport => 'PDF-Export';

  @override
  String get premiumFeatureSharing => 'Dokumente teilen';

  @override
  String get premiumFeatureOcr => 'Texterkennung (OCR)';

  @override
  String premiumPurchaseButton(String price) {
    return 'Für $price freischalten';
  }

  @override
  String get premiumRestorePurchases => 'Käufe wiederherstellen';

  @override
  String get premiumLater => 'Vielleicht später';

  @override
  String get premiumBadgeLabel => 'Premium';

  @override
  String get premiumStatusPremium => 'Premium';

  @override
  String get premiumStatusPremiumSubtitle => 'Alle Funktionen freigeschaltet';

  @override
  String get premiumStatusFree => 'Kostenlos';

  @override
  String premiumStatusFreeSubtitle(int remaining, int total) {
    return '$remaining von $total Scans übrig';
  }

  @override
  String get premiumScansRemaining => 'Verbleibende Scans';

  @override
  String get premiumUpgradeButton => 'Auf Premium upgraden';

  @override
  String get premiumDebugToggleTitle => 'Premium simulieren (Debug)';

  @override
  String get premiumDebugToggleSubtitle =>
      'Alle Premium-Funktionen zum Testen aktivieren';

  @override
  String get premiumDebugResetScans => 'Scan-Zähler zurücksetzen';

  @override
  String get premiumDebugResetSuccess => 'Scan-Zähler zurückgesetzt';

  @override
  String get premiumBlockedNoScans =>
      'Sie haben alle kostenlosen Scans aufgebraucht';

  @override
  String get premiumRequiredTitle => 'Premium erforderlich';

  @override
  String get premiumRequiredMessage =>
      'Diese Funktion erfordert ein Premium-Abonnement';

  @override
  String get premiumFeatureLockedOcr =>
      'OCR-Texterkennung ist eine Premium-Funktion';

  @override
  String get premiumFeatureLockedExport =>
      'PDF-Export ist eine Premium-Funktion';

  @override
  String get premiumFeatureLockedShare =>
      'Dokumente teilen ist eine Premium-Funktion';

  @override
  String get premiumFeatureLockedMultipage =>
      'Mehrseitiges Scannen ist eine Premium-Funktion';
}
