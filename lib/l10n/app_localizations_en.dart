// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Scanai';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeAuto => 'Auto';

  @override
  String get security => 'Lock';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get enableLockTitle => 'Enable lock?';

  @override
  String get enableLockMessage =>
      'Would you like to secure access to your documents with your fingerprint?';

  @override
  String get cancel => 'Cancel';

  @override
  String get enable => 'Enable';

  @override
  String get lockTimeoutImmediate => 'Immediate';

  @override
  String get lockTimeout1Min => '1 min';

  @override
  String get lockTimeout5Min => '5 min';

  @override
  String get lockTimeout30Min => '30 min';

  @override
  String get about => 'About';

  @override
  String get developedWith => 'Developed with';

  @override
  String get securityDetails => 'Security details';

  @override
  String get securityTitle => 'Security';

  @override
  String get aes256 => 'AES-256';

  @override
  String get localEncryption => 'Local encryption';

  @override
  String get zeroKnowledge => 'Zero-Knowledge';

  @override
  String get exclusiveAccess => 'Exclusive access';

  @override
  String get offline => 'Offline';

  @override
  String get securedPercent => '100% secured';

  @override
  String get settingsSpeechBubbleLine1 => 'Let\'s fine-tune';

  @override
  String get settingsSpeechBubbleLine2 => 'our application';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get myDocuments => 'My documents';

  @override
  String get scan => 'Scan';

  @override
  String get share => 'Share';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get noDocuments => 'No documents';

  @override
  String get scanYourFirstDocument => 'Scan your first document';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
      zero: 'No documents',
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
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get randomMessage1 => 'Need a PDF?';

  @override
  String get randomMessage2 => 'Let\'s Go?';

  @override
  String get randomMessage3 => 'Awaiting your orders!';

  @override
  String get randomMessage4 => 'Let\'s go!';

  @override
  String get ocrResults => 'OCR Results';

  @override
  String get text => 'Text';

  @override
  String get metadata => 'Metadata';

  @override
  String get copyText => 'Copy';

  @override
  String get textCopied => 'Text copied';

  @override
  String get noTextExtracted => 'No text extracted';

  @override
  String get language => 'Language';

  @override
  String get processingTime => 'Processing time';

  @override
  String get wordCount => 'Word count';

  @override
  String get lineCount => 'Line count';

  @override
  String get confidence => 'Confidence';

  @override
  String get shareAs => 'Share as';

  @override
  String get pdf => 'PDF';

  @override
  String get images => 'Images';

  @override
  String get ocrText => 'OCR Text';

  @override
  String get appLanguage => 'App language';

  @override
  String get ocrLanguage => 'OCR language';

  @override
  String get systemLanguage => 'System';

  @override
  String get french => 'Francais';

  @override
  String get english => 'English';

  @override
  String get ocrLanguageAuto => 'Automatic';

  @override
  String get ocrLanguageLatin => 'Latin (EN, FR, ES...)';

  @override
  String get ocrLanguageChinese => 'Chinese';

  @override
  String get ocrLanguageJapanese => 'Japanese';

  @override
  String get ocrLanguageKorean => 'Korean';

  @override
  String get ocrLanguageDevanagari => 'Devanagari';

  @override
  String get scanDocument => 'Scan a\ndocument';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get recentScans => 'Recent scans';

  @override
  String get allDocuments => 'View my files';

  @override
  String get searchDocuments => 'Search documents';

  @override
  String get sortByDate => 'Sort by date';

  @override
  String get sortByName => 'Sort by name';

  @override
  String get deleteConfirmTitle => 'Delete document?';

  @override
  String get deleteConfirmMessage =>
      'This action cannot be undone. The document will be permanently deleted.';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get retry => 'Retry';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get extractText => 'Extract text';

  @override
  String get extractingText => 'Extracting text...';

  @override
  String get documentName => 'Document name';

  @override
  String get enterDocumentName => 'Enter document name';

  @override
  String get createdAt => 'Created';

  @override
  String get modifiedAt => 'Modified';

  @override
  String get size => 'Size';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get languageSettings => 'Language settings';

  @override
  String get openingScanner => 'Opening scanner...';

  @override
  String get savingDocument => 'Saving document...';

  @override
  String get launchingScanner => 'Launching scanner...';

  @override
  String documentExportedTo(String folder) {
    return 'Document exported to $folder';
  }

  @override
  String get abandonScanTitle => 'Abandon scan?';

  @override
  String get abandonScanMessage =>
      'Are you sure you want to abandon this scan? This action cannot be undone.';

  @override
  String get abandon => 'Abandon';

  @override
  String get scanSuccessMessage => 'Done, it\'s in the box!';

  @override
  String get savePromptMessage => 'Shall we save it?';

  @override
  String get searchFolder => 'Search folder...';

  @override
  String get newFolder => 'New';

  @override
  String get folderCreationFailed => 'Folder creation failed';

  @override
  String get myDocs => 'My Docs';

  @override
  String get saveHere => 'Save here';

  @override
  String get export => 'Export';

  @override
  String get ocr => 'OCR';

  @override
  String get finish => 'Finish';

  @override
  String get move => 'Move';

  @override
  String get decrypting => 'Decrypting...';

  @override
  String get loading => 'Loading...';

  @override
  String get unableToLoadImage => 'Unable to load image';

  @override
  String get noTextDetected => 'No text detected in document';

  @override
  String get noTextToShare => 'No text to share';

  @override
  String get shareError => 'Share error';

  @override
  String get folderCreationError => 'Error creating folder';

  @override
  String get favoriteUpdateFailed => 'Failed to update favorites';

  @override
  String get documentExported => 'Document exported';

  @override
  String documentsExported(int count) {
    return '$count documents exported';
  }

  @override
  String get title => 'Title';

  @override
  String get pages => 'Pages';

  @override
  String get format => 'Format';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String daysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get lastUpdated => 'Last updated';

  @override
  String folderSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders selected',
      one: '1 folder selected',
    );
    return '$_temp0';
  }

  @override
  String documentSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents selected',
      one: '1 document selected',
    );
    return '$_temp0';
  }

  @override
  String get currentFolder => 'Current folder';

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get noFavorites => 'No favorites';

  @override
  String get copy => 'Copy';

  @override
  String get selectAll => 'Select all';

  @override
  String get selectionModeActive => 'Selection mode active';

  @override
  String get longPressToSelect => 'Long press to select';

  @override
  String get selectTextEasily => 'Select text easily';

  @override
  String get selection => 'Selection';

  @override
  String wordSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words selected',
      one: '1 word selected',
    );
    return '$_temp0';
  }

  @override
  String get renameDocument => 'Rename document';

  @override
  String get newTitle => 'New title...';

  @override
  String get saveUnder => 'Save under...';

  @override
  String moveDocuments(int count) {
    return 'Move $count documents';
  }

  @override
  String get chooseDestinationFolder => 'Choose a destination folder';

  @override
  String get rootFolder => 'Root (no folder)';

  @override
  String get createNewFolder => 'Create new folder';

  @override
  String get singleDocumentCompressed => 'Single compressed document';

  @override
  String get originalQualityPng => 'Original quality (PNG)';

  @override
  String get pleaseWait => 'Please wait...';

  @override
  String get somethingWentWrong => 'Oops! Something went wrong';

  @override
  String get editFolder => 'Edit folder';

  @override
  String get folderName => 'Folder name...';

  @override
  String get create => 'Create';

  @override
  String get nameCannotBeEmpty => 'Name cannot be empty';

  @override
  String get createFolderToOrganize =>
      'Create a folder to organize your documents';

  @override
  String get createFolder => 'Create folder';

  @override
  String get appIsLocked => 'Scanai is locked';

  @override
  String get authenticateToAccess =>
      'Authenticate to access your secured documents.';

  @override
  String get unlock => 'Unlock';

  @override
  String get preparingImage => 'Preparing image...';

  @override
  String get celebrationMessage1 => 'Easy!';

  @override
  String get celebrationMessage2 => 'Again?!';

  @override
  String get celebrationMessage3 => 'Need me again?';

  @override
  String get celebrationMessage4 => 'One more done!';

  @override
  String get celebrationMessage5 => 'Work done!';

  @override
  String get celebrationMessage6 => 'Next!';

  @override
  String get shareAppText =>
      'I use Scanai to secure and organize my important documents. It\'s fast, secure and smooth!';

  @override
  String get shareAppSubject => 'Scanai: Your secure pocket scanner';

  @override
  String get secureYourDocuments => 'Secure your documents';

  @override
  String get savedLocally => 'Everything saved locally';

  @override
  String documentsSecured(int count) {
    return '$count documents secured';
  }

  @override
  String get preferences => 'Preferences';

  @override
  String get interface => 'Interface';

  @override
  String get textRecognition => 'Text recognition';

  @override
  String get search => 'Search...';

  @override
  String nDocumentsLabel(int count) {
    return '$count documents';
  }

  @override
  String nFoldersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count folders',
      one: '1 folder',
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
      other: '$folders folders',
      one: '1 folder',
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
  String get scanner => 'Scan';

  @override
  String get sortAndFilter => 'Sort & Filter';

  @override
  String get clearAll => 'Clear all';

  @override
  String get sortBy => 'Sort by';

  @override
  String get quickFilters => 'Quick Filters';

  @override
  String get folder => 'Folder';

  @override
  String get tags => 'Tags';

  @override
  String get apply => 'Apply';

  @override
  String get favoritesOnly => 'Favorites only';

  @override
  String get favoritesOnlyDescription =>
      'Show only documents marked as favorite';

  @override
  String get hasOcrText => 'Has OCR text';

  @override
  String get hasOcrTextDescription => 'Show only documents with extracted text';

  @override
  String get failedToLoadFolders => 'Failed to load folders';

  @override
  String get noFoldersYet => 'No folders created yet';

  @override
  String get allDocumentsFilter => 'All Documents';

  @override
  String get failedToLoadTags => 'Failed to load tags';

  @override
  String get noTagsYet => 'No tags created yet';

  @override
  String get initializingOcr => 'Initializing OCR...';

  @override
  String get ocrSaved => 'OCR text saved to document';

  @override
  String copiedWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count words',
      one: '1 word',
    );
    return 'Copied $_temp0 to clipboard';
  }

  @override
  String get failedToCopyText => 'Failed to copy text to clipboard';

  @override
  String get searchInText => 'Search in text...';

  @override
  String matchesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count matches found',
      one: '1 match found',
    );
    return '$_temp0';
  }

  @override
  String get done => 'Done';

  @override
  String get extractingTextProgress => 'Extracting text...';

  @override
  String processingPage(int current, int total) {
    return 'Processing page $current of $total';
  }

  @override
  String get thisMayTakeAMoment => 'This may take a moment';

  @override
  String get scrollDisabledInSelectionMode =>
      'Selection mode active - scroll disabled';

  @override
  String get words => 'Words';

  @override
  String get lines => 'Lines';

  @override
  String get time => 'Time';

  @override
  String get noTextFound => 'No text found';

  @override
  String get noTextFoundDescription =>
      'The image may not contain readable text,\nor the quality may be too low.';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get extractTextTitle => 'Extract Text';

  @override
  String get extractTextDescription =>
      'Run OCR to extract readable text\nfrom this document.';

  @override
  String get runOcr => 'Run OCR';

  @override
  String get allProcessingLocal =>
      'All processing happens locally on your device';

  @override
  String get ocrOptions => 'OCR Options';

  @override
  String get documentType => 'Document Type';

  @override
  String get auto => 'Auto';

  @override
  String get singleColumn => 'Single Column';

  @override
  String get singleBlock => 'Single Block';

  @override
  String get sparseText => 'Sparse Text';

  @override
  String get rerunOcr => 'Re-run OCR';

  @override
  String get saveToDocument => 'Save to Document';

  @override
  String get copySelection => 'Copy Selection';

  @override
  String get copySelectionTooltip => 'Copy selected text to clipboard';

  @override
  String get searchInTextTooltip => 'Search in text';

  @override
  String get copyAllTextTooltip => 'Copy all text';

  @override
  String get shareTextTooltip => 'Share text';

  @override
  String get loadingDocuments => 'Loading your documents...';

  @override
  String get exportFailed => 'Export failed';

  @override
  String get whatAreYouLookingFor => 'What are you looking for?';
}
