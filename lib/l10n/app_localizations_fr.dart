// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Scanai';

  @override
  String get settings => 'Reglages';

  @override
  String get appearance => 'Apparence';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeAuto => 'Auto';

  @override
  String get security => 'Verrouillage';

  @override
  String get enabled => 'Active';

  @override
  String get disabled => 'Desactive';

  @override
  String get enableLockTitle => 'Activer le verrouillage ?';

  @override
  String get enableLockMessage =>
      'Souhaitez-vous securiser l\'acces a vos documents avec votre empreinte digitale ?';

  @override
  String get cancel => 'Annuler';

  @override
  String get enable => 'Activer';

  @override
  String get lockTimeoutImmediate => 'Immediat';

  @override
  String get lockTimeout1Min => '1 min';

  @override
  String get lockTimeout5Min => '5 min';

  @override
  String get lockTimeout30Min => '30 min';

  @override
  String get about => 'A propos';

  @override
  String get developedWith => 'Developpee avec le';

  @override
  String get securityDetails => 'Details securite';

  @override
  String get securityTitle => 'Securite';

  @override
  String get aes256 => 'AES-256';

  @override
  String get localEncryption => 'Chiffrement local';

  @override
  String get zeroKnowledge => 'Zero-Knowledge';

  @override
  String get exclusiveAccess => 'Acces exclusif';

  @override
  String get offline => 'Hors-ligne';

  @override
  String get securedPercent => '100% securise';

  @override
  String get settingsSpeechBubbleLine1 => 'On peaufine';

  @override
  String get settingsSpeechBubbleLine2 => 'notre application';

  @override
  String get dismiss => 'Fermer';

  @override
  String get myDocuments => 'Mes documents';

  @override
  String get scan => 'Scanner';

  @override
  String get share => 'Partager';

  @override
  String get delete => 'Supprimer';

  @override
  String get rename => 'Renommer';

  @override
  String get noDocuments => 'Aucun document';

  @override
  String get scanYourFirstDocument => 'Scannez votre premier document';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
      zero: 'Aucun document',
    );
    return '$_temp0';
  }

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get greetingMorning => 'Bonjour';

  @override
  String get greetingAfternoon => 'Bon apres-midi';

  @override
  String get greetingEvening => 'Bonsoir';

  @override
  String get randomMessage1 => 'Besoin d\'un PDF ?';

  @override
  String get randomMessage2 => 'Let\'s Go ?';

  @override
  String get randomMessage3 => 'J\'attends tes ordres !';

  @override
  String get randomMessage4 => 'Allons-y !';

  @override
  String get ocrResults => 'Resultats OCR';

  @override
  String get text => 'Texte';

  @override
  String get metadata => 'Metadonnees';

  @override
  String get copyText => 'Copier';

  @override
  String get textCopied => 'Texte copie';

  @override
  String get noTextExtracted => 'Aucun texte extrait';

  @override
  String get language => 'Langue';

  @override
  String get processingTime => 'Temps de traitement';

  @override
  String get wordCount => 'Nombre de mots';

  @override
  String get lineCount => 'Nombre de lignes';

  @override
  String get confidence => 'Confiance';

  @override
  String get shareAs => 'Partager au format';

  @override
  String get pdf => 'PDF';

  @override
  String get images => 'Images';

  @override
  String get ocrText => 'Texte OCR';

  @override
  String get appLanguage => 'Langue de l\'application';

  @override
  String get ocrLanguage => 'Langue OCR';

  @override
  String get systemLanguage => 'Systeme';

  @override
  String get french => 'Francais';

  @override
  String get english => 'English';

  @override
  String get ocrLanguageAuto => 'Automatique';

  @override
  String get ocrLanguageLatin => 'Latin (FR, EN, ES...)';

  @override
  String get ocrLanguageChinese => 'Chinois';

  @override
  String get ocrLanguageJapanese => 'Japonais';

  @override
  String get ocrLanguageKorean => 'Coreen';

  @override
  String get ocrLanguageDevanagari => 'Devanagari';

  @override
  String get scanDocument => 'Scanner un\ndocument';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Galerie';

  @override
  String get recentScans => 'Scans recents';

  @override
  String get allDocuments => 'Voir mes fichiers';

  @override
  String get searchDocuments => 'Rechercher des documents';

  @override
  String get sortByDate => 'Trier par date';

  @override
  String get sortByName => 'Trier par nom';

  @override
  String get deleteConfirmTitle => 'Supprimer le document ?';

  @override
  String get deleteConfirmMessage =>
      'Cette action est irreversible. Le document sera definitivement supprime.';

  @override
  String get errorOccurred => 'Une erreur est survenue';

  @override
  String get retry => 'Reessayer';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get save => 'Enregistrer';

  @override
  String get close => 'Fermer';

  @override
  String get extractText => 'Extraire le texte';

  @override
  String get extractingText => 'Extraction du texte...';

  @override
  String get documentName => 'Nom du document';

  @override
  String get enterDocumentName => 'Entrez le nom du document';

  @override
  String get createdAt => 'Cree le';

  @override
  String get modifiedAt => 'Modifie le';

  @override
  String get size => 'Taille';

  @override
  String get selectLanguage => 'Selectionner la langue';

  @override
  String get languageSettings => 'Parametres de langue';

  @override
  String get openingScanner => 'Ouverture du scanner...';

  @override
  String get savingDocument => 'Enregistrement du document...';

  @override
  String get launchingScanner => 'Lancement du scanner...';

  @override
  String documentExportedTo(String folder) {
    return 'Document exporte vers $folder';
  }

  @override
  String get abandonScanTitle => 'Abandonner le scan ?';

  @override
  String get abandonScanMessage =>
      'Etes-vous sur de vouloir abandonner ce scan ? Cette action est irreversible.';

  @override
  String get abandon => 'Abandonner';

  @override
  String get scanSuccessMessage => 'Hop, c\'est dans la boite !';

  @override
  String get savePromptMessage => 'On l\'enregistre ?';

  @override
  String get searchFolder => 'Rechercher un dossier...';

  @override
  String get newFolder => 'Nouveau';

  @override
  String get folderCreationFailed => 'Echec creation dossier';

  @override
  String get myDocs => 'Mes Docs';

  @override
  String get saveHere => 'Enregistrer ici';

  @override
  String get export => 'Exporter';

  @override
  String get ocr => 'OCR';

  @override
  String get finish => 'Terminer';

  @override
  String get move => 'Deplacer';

  @override
  String get decrypting => 'Dechiffrement...';

  @override
  String get loading => 'Chargement...';

  @override
  String get unableToLoadImage => 'Impossible de charger l\'image';

  @override
  String get noTextDetected => 'Aucun texte detecte dans le document';

  @override
  String get noTextToShare => 'Aucun texte a partager';

  @override
  String get shareError => 'Erreur de partage';

  @override
  String get folderCreationError => 'Erreur lors de la creation du dossier';

  @override
  String get favoriteUpdateFailed => 'Echec de la mise a jour des favoris';

  @override
  String get documentExported => 'Document exporte';

  @override
  String documentsExported(int count) {
    return '$count documents exportes';
  }

  @override
  String get title => 'Titre';

  @override
  String get pages => 'Pages';

  @override
  String get format => 'Format';

  @override
  String get justNow => 'A l\'instant';

  @override
  String minutesAgo(int minutes) {
    return 'Il y a $minutes min';
  }

  @override
  String hoursAgo(int hours) {
    return 'Il y a ${hours}h';
  }

  @override
  String daysAgo(int days) {
    return 'Il y a $days jours';
  }

  @override
  String get lastUpdated => 'Derniere mise a jour';

  @override
  String folderSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dossiers selectionnes',
      one: '1 dossier selectionne',
    );
    return '$_temp0';
  }

  @override
  String documentSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents selectionnes',
      one: '1 document selectionne',
    );
    return '$_temp0';
  }

  @override
  String get currentFolder => 'Dossier actuel';

  @override
  String noResultsFor(String query) {
    return 'Aucun resultat pour \"$query\"';
  }

  @override
  String get noFavorites => 'Aucun favori';

  @override
  String get copy => 'Copier';

  @override
  String get selectAll => 'Tout selectionner';

  @override
  String get selectionModeActive => 'Mode selection actif';

  @override
  String get longPressToSelect => 'Appui long pour selectionner';

  @override
  String get selectTextEasily => 'Selectionnez le texte facilement';

  @override
  String get selection => 'Selection';

  @override
  String wordSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots selectionnes',
      one: '1 mot selectionne',
    );
    return '$_temp0';
  }

  @override
  String get renameDocument => 'Renommer le document';

  @override
  String get newTitle => 'Nouveau titre...';

  @override
  String get saveUnder => 'Enregistrer sous...';

  @override
  String moveDocuments(int count) {
    return 'Deplacer $count documents';
  }

  @override
  String get chooseDestinationFolder => 'Choisis un dossier de destination';

  @override
  String get rootFolder => 'Racine (sans dossier)';

  @override
  String get createNewFolder => 'Creer un nouveau dossier';

  @override
  String get singleDocumentCompressed => 'Document unique compresse';

  @override
  String get originalQualityPng => 'Qualite originale (PNG)';

  @override
  String get pleaseWait => 'Un instant s\'il vous plait...';

  @override
  String get somethingWentWrong => 'Oups ! Quelque chose a mal tourne';

  @override
  String get editFolder => 'Modifier le dossier';

  @override
  String get folderName => 'Nom du dossier...';

  @override
  String get create => 'Creer';

  @override
  String get nameCannotBeEmpty => 'Le nom ne peut pas etre vide';

  @override
  String get createFolderToOrganize =>
      'Creez un dossier pour organiser vos documents';

  @override
  String get createFolder => 'Creer un dossier';

  @override
  String get appIsLocked => 'Scanai est verrouille';

  @override
  String get authenticateToAccess =>
      'Authentifiez-vous pour acceder a vos documents securises.';

  @override
  String get unlock => 'Deverrouiller';

  @override
  String get preparingImage => 'Preparation de l\'image...';

  @override
  String get celebrationMessage1 => 'Easy !';

  @override
  String get celebrationMessage2 => 'On r\'commence ?!';

  @override
  String get celebrationMessage3 => 'Encore besoin de moi ?';

  @override
  String get celebrationMessage4 => 'Et hop, un de plus !';

  @override
  String get celebrationMessage5 => 'Travail termine !';

  @override
  String get celebrationMessage6 => 'Au suivant!';

  @override
  String get shareAppText =>
      'J\'utilise Scanai pour securiser et classer mes documents importants. C\'est rapide, securise et ultra-fluide !';

  @override
  String get shareAppSubject => 'Scanai : Ton scanner de poche securise';

  @override
  String get secureYourDocuments => 'Securisez vos documents';

  @override
  String get savedLocally => 'Tout est sauvegarde localement';

  @override
  String documentsSecured(int count) {
    return '$count documents securises';
  }

  @override
  String get preferences => 'Preferences';

  @override
  String get interface => 'Interface';

  @override
  String get textRecognition => 'Reconnaissance texte';

  @override
  String get search => 'Rechercher...';

  @override
  String nDocumentsLabel(int count) {
    return '$count documents';
  }

  @override
  String nFoldersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dossiers',
      one: '1 dossier',
    );
    return '$_temp0';
  }

  @override
  String nDocs(int count) {
    return '$count docs';
  }

  @override
  String foldersAndDocs(int folders, int documents) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders dossiers',
      one: '1 dossier',
    );
    String _temp1 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents documents',
      one: '1 document',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get scanner => 'Scanner';

  @override
  String get sortAndFilter => 'Trier et Filtrer';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get sortBy => 'Trier par';

  @override
  String get quickFilters => 'Filtres rapides';

  @override
  String get folder => 'Dossier';

  @override
  String get tags => 'Tags';

  @override
  String get apply => 'Appliquer';

  @override
  String get favoritesOnly => 'Favoris uniquement';

  @override
  String get favoritesOnlyDescription =>
      'Afficher uniquement les documents marques comme favoris';

  @override
  String get hasOcrText => 'Contient du texte OCR';

  @override
  String get hasOcrTextDescription =>
      'Afficher uniquement les documents avec du texte extrait';

  @override
  String get failedToLoadFolders => 'Echec du chargement des dossiers';

  @override
  String get noFoldersYet => 'Aucun dossier cree';

  @override
  String get allDocumentsFilter => 'Tous les documents';

  @override
  String get failedToLoadTags => 'Echec du chargement des tags';

  @override
  String get noTagsYet => 'Aucun tag cree';

  @override
  String get initializingOcr => 'Initialisation OCR...';

  @override
  String get ocrSaved => 'Texte OCR sauvegarde dans le document';

  @override
  String copiedWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mots copies',
      one: '1 mot copie',
    );
    return '$_temp0 dans le presse-papiers';
  }

  @override
  String get failedToCopyText => 'Echec de la copie du texte';

  @override
  String get searchInText => 'Rechercher dans le texte...';

  @override
  String matchesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultats trouves',
      one: '1 resultat trouve',
    );
    return '$_temp0';
  }

  @override
  String get done => 'Termine';

  @override
  String get extractingTextProgress => 'Extraction du texte...';

  @override
  String processingPage(int current, int total) {
    return 'Traitement de la page $current sur $total';
  }

  @override
  String get thisMayTakeAMoment => 'Cela peut prendre un moment';

  @override
  String get scrollDisabledInSelectionMode =>
      'Mode selection actif - defilement desactive';

  @override
  String get words => 'Mots';

  @override
  String get lines => 'Lignes';

  @override
  String get time => 'Temps';

  @override
  String get noTextFound => 'Aucun texte trouve';

  @override
  String get noTextFoundDescription =>
      'L\'image ne contient peut-etre pas de texte lisible,\nou la qualite est trop basse.';

  @override
  String get tryAgain => 'Reessayer';

  @override
  String get extractTextTitle => 'Extraire le texte';

  @override
  String get extractTextDescription =>
      'Lancez l\'OCR pour extraire le texte\nde ce document.';

  @override
  String get runOcr => 'Lancer OCR';

  @override
  String get allProcessingLocal =>
      'Tout le traitement se fait localement sur votre appareil';

  @override
  String get ocrOptions => 'Options OCR';

  @override
  String get documentType => 'Type de document';

  @override
  String get auto => 'Auto';

  @override
  String get singleColumn => 'Colonne unique';

  @override
  String get singleBlock => 'Bloc unique';

  @override
  String get sparseText => 'Texte epars';

  @override
  String get rerunOcr => 'Relancer OCR';

  @override
  String get saveToDocument => 'Sauvegarder dans le document';

  @override
  String get copySelection => 'Copier la selection';

  @override
  String get copySelectionTooltip => 'Copier le texte selectionne';

  @override
  String get searchInTextTooltip => 'Rechercher dans le texte';

  @override
  String get copyAllTextTooltip => 'Copier tout le texte';

  @override
  String get shareTextTooltip => 'Partager le texte';

  @override
  String get loadingDocuments => 'Chargement de vos documents...';

  @override
  String get exportFailed => 'Echec de l\'exportation';

  @override
  String get whatAreYouLookingFor => 'Que cherches-tu ?';

  @override
  String get needHelp => 'Besoin d\'aide ?';
}
