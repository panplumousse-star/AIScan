import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// The application title
  ///
  /// In fr, this message translates to:
  /// **'Scanai'**
  String get appTitle;

  /// Settings screen title
  ///
  /// In fr, this message translates to:
  /// **'Reglages'**
  String get settings;

  /// Appearance section title
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get appearance;

  /// Light theme option
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// Dark theme option
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// Auto/System theme option
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// Security/Lock section title
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage'**
  String get security;

  /// Enabled state label
  ///
  /// In fr, this message translates to:
  /// **'Active'**
  String get enabled;

  /// Disabled state label
  ///
  /// In fr, this message translates to:
  /// **'Desactive'**
  String get disabled;

  /// Enable lock dialog title
  ///
  /// In fr, this message translates to:
  /// **'Activer le verrouillage ?'**
  String get enableLockTitle;

  /// Enable lock dialog message
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous securiser l\'acces a vos documents avec votre empreinte digitale ?'**
  String get enableLockMessage;

  /// Cancel button label
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// Enable button label
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get enable;

  /// Immediate lock timeout
  ///
  /// In fr, this message translates to:
  /// **'Immediat'**
  String get lockTimeoutImmediate;

  /// 1 minute lock timeout
  ///
  /// In fr, this message translates to:
  /// **'1 min'**
  String get lockTimeout1Min;

  /// 5 minutes lock timeout
  ///
  /// In fr, this message translates to:
  /// **'5 min'**
  String get lockTimeout5Min;

  /// 30 minutes lock timeout
  ///
  /// In fr, this message translates to:
  /// **'30 min'**
  String get lockTimeout30Min;

  /// About section title
  ///
  /// In fr, this message translates to:
  /// **'A propos'**
  String get about;

  /// Developed with love text
  ///
  /// In fr, this message translates to:
  /// **'Developpee avec le'**
  String get developedWith;

  /// Security details hint
  ///
  /// In fr, this message translates to:
  /// **'Details securite'**
  String get securityDetails;

  /// Security info title
  ///
  /// In fr, this message translates to:
  /// **'Securite'**
  String get securityTitle;

  /// AES-256 encryption label
  ///
  /// In fr, this message translates to:
  /// **'AES-256'**
  String get aes256;

  /// Local encryption description
  ///
  /// In fr, this message translates to:
  /// **'Chiffrement local'**
  String get localEncryption;

  /// Zero-Knowledge label
  ///
  /// In fr, this message translates to:
  /// **'Zero-Knowledge'**
  String get zeroKnowledge;

  /// Exclusive access description
  ///
  /// In fr, this message translates to:
  /// **'Acces exclusif'**
  String get exclusiveAccess;

  /// Offline label
  ///
  /// In fr, this message translates to:
  /// **'Hors-ligne'**
  String get offline;

  /// 100% secured description
  ///
  /// In fr, this message translates to:
  /// **'100% securise'**
  String get securedPercent;

  /// Settings mascot speech bubble line 1
  ///
  /// In fr, this message translates to:
  /// **'On peaufine'**
  String get settingsSpeechBubbleLine1;

  /// Settings mascot speech bubble line 2
  ///
  /// In fr, this message translates to:
  /// **'notre application'**
  String get settingsSpeechBubbleLine2;

  /// Dismiss/close button label
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get dismiss;

  /// My documents label
  ///
  /// In fr, this message translates to:
  /// **'Mes documents'**
  String get myDocuments;

  /// Scan action label
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get scan;

  /// Share action label
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// Delete action label
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// Rename action label
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get rename;

  /// No documents message
  ///
  /// In fr, this message translates to:
  /// **'Aucun document'**
  String get noDocuments;

  /// Prompt to scan first document
  ///
  /// In fr, this message translates to:
  /// **'Scannez votre premier document'**
  String get scanYourFirstDocument;

  /// Document count with plural forms
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun document} =1{1 document} other{{count} documents}}'**
  String documentCount(int count);

  /// Page count with plural forms
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String pageCount(int count);

  /// Morning greeting
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get greetingMorning;

  /// Afternoon greeting
  ///
  /// In fr, this message translates to:
  /// **'Bon apres-midi'**
  String get greetingAfternoon;

  /// Evening greeting
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir'**
  String get greetingEvening;

  /// Random motivational message 1
  ///
  /// In fr, this message translates to:
  /// **'Pret a numeriser ?'**
  String get randomMessage1;

  /// Random motivational message 2
  ///
  /// In fr, this message translates to:
  /// **'Vos documents en securite'**
  String get randomMessage2;

  /// Random motivational message 3
  ///
  /// In fr, this message translates to:
  /// **'Scanner, c\'est preserver'**
  String get randomMessage3;

  /// Random motivational message 4
  ///
  /// In fr, this message translates to:
  /// **'Tout est sous controle'**
  String get randomMessage4;

  /// Random motivational message 5
  ///
  /// In fr, this message translates to:
  /// **'La simplicite avant tout'**
  String get randomMessage5;

  /// OCR results screen title
  ///
  /// In fr, this message translates to:
  /// **'Resultats OCR'**
  String get ocrResults;

  /// Text tab label
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get text;

  /// Metadata tab label
  ///
  /// In fr, this message translates to:
  /// **'Metadonnees'**
  String get metadata;

  /// Copy text action
  ///
  /// In fr, this message translates to:
  /// **'Copier le texte'**
  String get copyText;

  /// Text copied confirmation
  ///
  /// In fr, this message translates to:
  /// **'Texte copie'**
  String get textCopied;

  /// No text extracted message
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte extrait'**
  String get noTextExtracted;

  /// Language label
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// Processing time label
  ///
  /// In fr, this message translates to:
  /// **'Temps de traitement'**
  String get processingTime;

  /// Word count label
  ///
  /// In fr, this message translates to:
  /// **'Nombre de mots'**
  String get wordCount;

  /// Line count label
  ///
  /// In fr, this message translates to:
  /// **'Nombre de lignes'**
  String get lineCount;

  /// Confidence score label
  ///
  /// In fr, this message translates to:
  /// **'Confiance'**
  String get confidence;

  /// Share as dialog title
  ///
  /// In fr, this message translates to:
  /// **'Partager comme'**
  String get shareAs;

  /// PDF format label
  ///
  /// In fr, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// Images format label
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get images;

  /// OCR text format label
  ///
  /// In fr, this message translates to:
  /// **'Texte OCR'**
  String get ocrText;

  /// App language setting title
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'application'**
  String get appLanguage;

  /// OCR language setting title
  ///
  /// In fr, this message translates to:
  /// **'Langue OCR'**
  String get ocrLanguage;

  /// System language option
  ///
  /// In fr, this message translates to:
  /// **'Systeme'**
  String get systemLanguage;

  /// French language name
  ///
  /// In fr, this message translates to:
  /// **'Francais'**
  String get french;

  /// English language name
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get english;

  /// Automatic OCR language detection
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get ocrLanguageAuto;

  /// Latin script OCR option
  ///
  /// In fr, this message translates to:
  /// **'Latin (FR, EN, ES...)'**
  String get ocrLanguageLatin;

  /// Chinese script OCR option
  ///
  /// In fr, this message translates to:
  /// **'Chinois'**
  String get ocrLanguageChinese;

  /// Japanese script OCR option
  ///
  /// In fr, this message translates to:
  /// **'Japonais'**
  String get ocrLanguageJapanese;

  /// Korean script OCR option
  ///
  /// In fr, this message translates to:
  /// **'Coreen'**
  String get ocrLanguageKorean;

  /// Devanagari script OCR option
  ///
  /// In fr, this message translates to:
  /// **'Devanagari'**
  String get ocrLanguageDevanagari;

  /// Scan document action
  ///
  /// In fr, this message translates to:
  /// **'Scanner un document'**
  String get scanDocument;

  /// Camera option
  ///
  /// In fr, this message translates to:
  /// **'Camera'**
  String get camera;

  /// Gallery option
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get gallery;

  /// Recent scans label
  ///
  /// In fr, this message translates to:
  /// **'Scans recents'**
  String get recentScans;

  /// All documents label
  ///
  /// In fr, this message translates to:
  /// **'Tous les documents'**
  String get allDocuments;

  /// Search documents placeholder
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des documents'**
  String get searchDocuments;

  /// Sort by date option
  ///
  /// In fr, this message translates to:
  /// **'Trier par date'**
  String get sortByDate;

  /// Sort by name option
  ///
  /// In fr, this message translates to:
  /// **'Trier par nom'**
  String get sortByName;

  /// Delete confirmation dialog title
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le document ?'**
  String get deleteConfirmTitle;

  /// Delete confirmation dialog message
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irreversible. Le document sera definitivement supprime.'**
  String get deleteConfirmMessage;

  /// Generic error message
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorOccurred;

  /// Retry action label
  ///
  /// In fr, this message translates to:
  /// **'Reessayer'**
  String get retry;

  /// OK button label
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// Yes button label
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get yes;

  /// No button label
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get no;

  /// Save action label
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// Close action label
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// Extract text OCR action
  ///
  /// In fr, this message translates to:
  /// **'Extraire le texte'**
  String get extractText;

  /// Extracting text loading message
  ///
  /// In fr, this message translates to:
  /// **'Extraction du texte...'**
  String get extractingText;

  /// Document name field label
  ///
  /// In fr, this message translates to:
  /// **'Nom du document'**
  String get documentName;

  /// Document name field placeholder
  ///
  /// In fr, this message translates to:
  /// **'Entrez le nom du document'**
  String get enterDocumentName;

  /// Created at label
  ///
  /// In fr, this message translates to:
  /// **'Cree le'**
  String get createdAt;

  /// Modified at label
  ///
  /// In fr, this message translates to:
  /// **'Modifie le'**
  String get modifiedAt;

  /// File size label
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get size;

  /// Select language dialog title
  ///
  /// In fr, this message translates to:
  /// **'Selectionner la langue'**
  String get selectLanguage;

  /// Language settings section title
  ///
  /// In fr, this message translates to:
  /// **'Parametres de langue'**
  String get languageSettings;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
