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
  String get randomMessage1 => 'Ready to scan?';

  @override
  String get randomMessage2 => 'Your documents are safe';

  @override
  String get randomMessage3 => 'Scan to preserve';

  @override
  String get randomMessage4 => 'Everything under control';

  @override
  String get randomMessage5 => 'Simplicity first';

  @override
  String get ocrResults => 'OCR Results';

  @override
  String get text => 'Text';

  @override
  String get metadata => 'Metadata';

  @override
  String get copyText => 'Copy text';

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
  String get scanDocument => 'Scan document';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get recentScans => 'Recent scans';

  @override
  String get allDocuments => 'All documents';

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
}
