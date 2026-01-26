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

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanai'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Reglages'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In fr, this message translates to:
  /// **'Apparence'**
  String get appearance;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @themeAuto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get themeAuto;

  /// No description provided for @security.
  ///
  /// In fr, this message translates to:
  /// **'Verrouillage'**
  String get security;

  /// No description provided for @enabled.
  ///
  /// In fr, this message translates to:
  /// **'Active'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In fr, this message translates to:
  /// **'Desactive'**
  String get disabled;

  /// No description provided for @enableLockTitle.
  ///
  /// In fr, this message translates to:
  /// **'Activer le verrouillage ?'**
  String get enableLockTitle;

  /// No description provided for @enableLockMessage.
  ///
  /// In fr, this message translates to:
  /// **'Souhaitez-vous securiser l\'acces a vos documents avec votre empreinte digitale ?'**
  String get enableLockMessage;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @enable.
  ///
  /// In fr, this message translates to:
  /// **'Activer'**
  String get enable;

  /// No description provided for @lockTimeoutImmediate.
  ///
  /// In fr, this message translates to:
  /// **'Immediat'**
  String get lockTimeoutImmediate;

  /// No description provided for @lockTimeout1Min.
  ///
  /// In fr, this message translates to:
  /// **'1 min'**
  String get lockTimeout1Min;

  /// No description provided for @lockTimeout5Min.
  ///
  /// In fr, this message translates to:
  /// **'5 min'**
  String get lockTimeout5Min;

  /// No description provided for @lockTimeout30Min.
  ///
  /// In fr, this message translates to:
  /// **'30 min'**
  String get lockTimeout30Min;

  /// No description provided for @about.
  ///
  /// In fr, this message translates to:
  /// **'A propos'**
  String get about;

  /// No description provided for @developedWith.
  ///
  /// In fr, this message translates to:
  /// **'Developpee avec le'**
  String get developedWith;

  /// No description provided for @securityDetails.
  ///
  /// In fr, this message translates to:
  /// **'Details securite'**
  String get securityDetails;

  /// No description provided for @securityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Securite'**
  String get securityTitle;

  /// No description provided for @aes256.
  ///
  /// In fr, this message translates to:
  /// **'AES-256'**
  String get aes256;

  /// No description provided for @localEncryption.
  ///
  /// In fr, this message translates to:
  /// **'Chiffrement local'**
  String get localEncryption;

  /// No description provided for @zeroKnowledge.
  ///
  /// In fr, this message translates to:
  /// **'Zero-Knowledge'**
  String get zeroKnowledge;

  /// No description provided for @exclusiveAccess.
  ///
  /// In fr, this message translates to:
  /// **'Acces exclusif'**
  String get exclusiveAccess;

  /// No description provided for @offline.
  ///
  /// In fr, this message translates to:
  /// **'Hors-ligne'**
  String get offline;

  /// No description provided for @securedPercent.
  ///
  /// In fr, this message translates to:
  /// **'100% securise'**
  String get securedPercent;

  /// No description provided for @settingsSpeechBubbleLine1.
  ///
  /// In fr, this message translates to:
  /// **'Un petit'**
  String get settingsSpeechBubbleLine1;

  /// No description provided for @settingsSpeechBubbleLine2.
  ///
  /// In fr, this message translates to:
  /// **'reglage ?'**
  String get settingsSpeechBubbleLine2;

  /// No description provided for @dismiss.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get dismiss;

  /// No description provided for @myDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Mes documents'**
  String get myDocuments;

  /// No description provided for @scan.
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get scan;

  /// No description provided for @share.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get share;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get rename;

  /// No description provided for @noDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Aucun document'**
  String get noDocuments;

  /// No description provided for @scanYourFirstDocument.
  ///
  /// In fr, this message translates to:
  /// **'Scannez votre premier document'**
  String get scanYourFirstDocument;

  /// No description provided for @documentCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun document} =1{1 document} other{{count} documents}}'**
  String documentCount(int count);

  /// No description provided for @pageCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String pageCount(int count);

  /// No description provided for @greetingMorning.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In fr, this message translates to:
  /// **'Bon apres-midi'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In fr, this message translates to:
  /// **'Bonsoir'**
  String get greetingEvening;

  /// No description provided for @randomMessage1.
  ///
  /// In fr, this message translates to:
  /// **'Besoin d\'un PDF ?'**
  String get randomMessage1;

  /// No description provided for @randomMessage2.
  ///
  /// In fr, this message translates to:
  /// **'Let\'s Go ?'**
  String get randomMessage2;

  /// No description provided for @randomMessage3.
  ///
  /// In fr, this message translates to:
  /// **'J\'attends tes ordres !'**
  String get randomMessage3;

  /// No description provided for @randomMessage4.
  ///
  /// In fr, this message translates to:
  /// **'Allons-y !'**
  String get randomMessage4;

  /// No description provided for @ocrResults.
  ///
  /// In fr, this message translates to:
  /// **'Resultats OCR'**
  String get ocrResults;

  /// No description provided for @text.
  ///
  /// In fr, this message translates to:
  /// **'Texte'**
  String get text;

  /// No description provided for @metadata.
  ///
  /// In fr, this message translates to:
  /// **'Metadonnees'**
  String get metadata;

  /// No description provided for @copyText.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copyText;

  /// No description provided for @textCopied.
  ///
  /// In fr, this message translates to:
  /// **'Texte copie'**
  String get textCopied;

  /// No description provided for @noTextExtracted.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte extrait'**
  String get noTextExtracted;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @processingTime.
  ///
  /// In fr, this message translates to:
  /// **'Temps de traitement'**
  String get processingTime;

  /// No description provided for @wordCount.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de mots'**
  String get wordCount;

  /// No description provided for @lineCount.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de lignes'**
  String get lineCount;

  /// No description provided for @confidence.
  ///
  /// In fr, this message translates to:
  /// **'Confiance'**
  String get confidence;

  /// No description provided for @shareAs.
  ///
  /// In fr, this message translates to:
  /// **'Partager au format'**
  String get shareAs;

  /// No description provided for @pdf.
  ///
  /// In fr, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @images.
  ///
  /// In fr, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @ocrText.
  ///
  /// In fr, this message translates to:
  /// **'Texte OCR'**
  String get ocrText;

  /// No description provided for @appLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue de l\'application'**
  String get appLanguage;

  /// No description provided for @ocrLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Langue OCR'**
  String get ocrLanguage;

  /// No description provided for @systemLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Systeme'**
  String get systemLanguage;

  /// No description provided for @french.
  ///
  /// In fr, this message translates to:
  /// **'Francais'**
  String get french;

  /// No description provided for @english.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @ocrLanguageAuto.
  ///
  /// In fr, this message translates to:
  /// **'Automatique'**
  String get ocrLanguageAuto;

  /// No description provided for @ocrLanguageLatin.
  ///
  /// In fr, this message translates to:
  /// **'Latin (FR, EN, ES...)'**
  String get ocrLanguageLatin;

  /// No description provided for @ocrLanguageChinese.
  ///
  /// In fr, this message translates to:
  /// **'Chinois'**
  String get ocrLanguageChinese;

  /// No description provided for @ocrLanguageJapanese.
  ///
  /// In fr, this message translates to:
  /// **'Japonais'**
  String get ocrLanguageJapanese;

  /// No description provided for @ocrLanguageKorean.
  ///
  /// In fr, this message translates to:
  /// **'Coreen'**
  String get ocrLanguageKorean;

  /// No description provided for @ocrLanguageDevanagari.
  ///
  /// In fr, this message translates to:
  /// **'Devanagari'**
  String get ocrLanguageDevanagari;

  /// No description provided for @scanDocument.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un\ndocument'**
  String get scanDocument;

  /// No description provided for @camera.
  ///
  /// In fr, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In fr, this message translates to:
  /// **'Galerie'**
  String get gallery;

  /// No description provided for @recentScans.
  ///
  /// In fr, this message translates to:
  /// **'Scans recents'**
  String get recentScans;

  /// No description provided for @allDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Voir mes fichiers'**
  String get allDocuments;

  /// No description provided for @searchDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher des documents'**
  String get searchDocuments;

  /// No description provided for @sortByDate.
  ///
  /// In fr, this message translates to:
  /// **'Trier par date'**
  String get sortByDate;

  /// No description provided for @sortByName.
  ///
  /// In fr, this message translates to:
  /// **'Trier par nom'**
  String get sortByName;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le document ?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In fr, this message translates to:
  /// **'Cette action est irreversible. Le document sera definitivement supprime.'**
  String get deleteConfirmMessage;

  /// No description provided for @errorOccurred.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue'**
  String get errorOccurred;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Reessayer'**
  String get retry;

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get no;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @extractText.
  ///
  /// In fr, this message translates to:
  /// **'Extraire le texte'**
  String get extractText;

  /// No description provided for @extractingText.
  ///
  /// In fr, this message translates to:
  /// **'Extraction du texte...'**
  String get extractingText;

  /// No description provided for @documentName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du document'**
  String get documentName;

  /// No description provided for @enterDocumentName.
  ///
  /// In fr, this message translates to:
  /// **'Entrez le nom du document'**
  String get enterDocumentName;

  /// No description provided for @createdAt.
  ///
  /// In fr, this message translates to:
  /// **'Cree le'**
  String get createdAt;

  /// No description provided for @modifiedAt.
  ///
  /// In fr, this message translates to:
  /// **'Modifie le'**
  String get modifiedAt;

  /// No description provided for @size.
  ///
  /// In fr, this message translates to:
  /// **'Taille'**
  String get size;

  /// No description provided for @selectLanguage.
  ///
  /// In fr, this message translates to:
  /// **'Selectionner la langue'**
  String get selectLanguage;

  /// No description provided for @languageSettings.
  ///
  /// In fr, this message translates to:
  /// **'Parametres de langue'**
  String get languageSettings;

  /// No description provided for @openingScanner.
  ///
  /// In fr, this message translates to:
  /// **'Ouverture du scanner...'**
  String get openingScanner;

  /// No description provided for @savingDocument.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement du document...'**
  String get savingDocument;

  /// No description provided for @launchingScanner.
  ///
  /// In fr, this message translates to:
  /// **'Lancement du scanner...'**
  String get launchingScanner;

  /// No description provided for @documentExportedTo.
  ///
  /// In fr, this message translates to:
  /// **'Document exporte vers {folder}'**
  String documentExportedTo(String folder);

  /// No description provided for @abandonScanTitle.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner le scan ?'**
  String get abandonScanTitle;

  /// No description provided for @abandonScanMessage.
  ///
  /// In fr, this message translates to:
  /// **'Etes-vous sur de vouloir abandonner ce scan ? Cette action est irreversible.'**
  String get abandonScanMessage;

  /// No description provided for @abandon.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get abandon;

  /// No description provided for @scanSuccessMessage.
  ///
  /// In fr, this message translates to:
  /// **'Hop, c\'est dans la boite !'**
  String get scanSuccessMessage;

  /// No description provided for @savePromptMessage.
  ///
  /// In fr, this message translates to:
  /// **'On l\'enregistre ?'**
  String get savePromptMessage;

  /// No description provided for @searchFolder.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher un dossier...'**
  String get searchFolder;

  /// No description provided for @newFolder.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get newFolder;

  /// No description provided for @folderCreationFailed.
  ///
  /// In fr, this message translates to:
  /// **'Echec creation dossier'**
  String get folderCreationFailed;

  /// No description provided for @myDocs.
  ///
  /// In fr, this message translates to:
  /// **'Mes Docs'**
  String get myDocs;

  /// No description provided for @saveHere.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer ici'**
  String get saveHere;

  /// No description provided for @export.
  ///
  /// In fr, this message translates to:
  /// **'Exporter'**
  String get export;

  /// No description provided for @ocr.
  ///
  /// In fr, this message translates to:
  /// **'OCR'**
  String get ocr;

  /// No description provided for @finish.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get finish;

  /// No description provided for @move.
  ///
  /// In fr, this message translates to:
  /// **'Deplacer'**
  String get move;

  /// No description provided for @decrypting.
  ///
  /// In fr, this message translates to:
  /// **'Dechiffrement...'**
  String get decrypting;

  /// No description provided for @loading.
  ///
  /// In fr, this message translates to:
  /// **'Chargement...'**
  String get loading;

  /// No description provided for @unableToLoadImage.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger l\'image'**
  String get unableToLoadImage;

  /// No description provided for @noTextDetected.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte detecte dans le document'**
  String get noTextDetected;

  /// No description provided for @noTextToShare.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte a partager'**
  String get noTextToShare;

  /// No description provided for @shareError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de partage'**
  String get shareError;

  /// No description provided for @folderCreationError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de la creation du dossier'**
  String get folderCreationError;

  /// No description provided for @favoriteUpdateFailed.
  ///
  /// In fr, this message translates to:
  /// **'Echec de la mise a jour des favoris'**
  String get favoriteUpdateFailed;

  /// No description provided for @documentExported.
  ///
  /// In fr, this message translates to:
  /// **'Document exporte'**
  String get documentExported;

  /// No description provided for @documentsExported.
  ///
  /// In fr, this message translates to:
  /// **'{count} documents exportes'**
  String documentsExported(int count);

  /// No description provided for @title.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get title;

  /// No description provided for @pages.
  ///
  /// In fr, this message translates to:
  /// **'Pages'**
  String get pages;

  /// No description provided for @format.
  ///
  /// In fr, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @justNow.
  ///
  /// In fr, this message translates to:
  /// **'A l\'instant'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {minutes} min'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {hours}h'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In fr, this message translates to:
  /// **'Il y a {days} jours'**
  String daysAgo(int days);

  /// No description provided for @lastUpdated.
  ///
  /// In fr, this message translates to:
  /// **'Derniere mise a jour'**
  String get lastUpdated;

  /// No description provided for @folderSelected.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 dossier selectionne} other{{count} dossiers selectionnes}}'**
  String folderSelected(int count);

  /// No description provided for @documentSelected.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 document selectionne} other{{count} documents selectionnes}}'**
  String documentSelected(int count);

  /// No description provided for @currentFolder.
  ///
  /// In fr, this message translates to:
  /// **'Dossier actuel'**
  String get currentFolder;

  /// No description provided for @noResultsFor.
  ///
  /// In fr, this message translates to:
  /// **'Aucun resultat pour \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @noFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Aucun favori'**
  String get noFavorites;

  /// No description provided for @copy.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get copy;

  /// No description provided for @selectAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout selectionner'**
  String get selectAll;

  /// No description provided for @selectionModeActive.
  ///
  /// In fr, this message translates to:
  /// **'Mode selection actif'**
  String get selectionModeActive;

  /// No description provided for @longPressToSelect.
  ///
  /// In fr, this message translates to:
  /// **'Appui long pour selectionner'**
  String get longPressToSelect;

  /// No description provided for @selectTextEasily.
  ///
  /// In fr, this message translates to:
  /// **'Selectionnez le texte facilement'**
  String get selectTextEasily;

  /// No description provided for @selection.
  ///
  /// In fr, this message translates to:
  /// **'Selection'**
  String get selection;

  /// No description provided for @wordSelected.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 mot selectionne} other{{count} mots selectionnes}}'**
  String wordSelected(int count);

  /// No description provided for @renameDocument.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le document'**
  String get renameDocument;

  /// No description provided for @newTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau titre...'**
  String get newTitle;

  /// No description provided for @saveUnder.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer sous...'**
  String get saveUnder;

  /// No description provided for @moveDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Deplacer {count} documents'**
  String moveDocuments(int count);

  /// No description provided for @chooseDestinationFolder.
  ///
  /// In fr, this message translates to:
  /// **'Choisis un dossier de destination'**
  String get chooseDestinationFolder;

  /// No description provided for @rootFolder.
  ///
  /// In fr, this message translates to:
  /// **'Racine (sans dossier)'**
  String get rootFolder;

  /// No description provided for @createNewFolder.
  ///
  /// In fr, this message translates to:
  /// **'Creer un nouveau dossier'**
  String get createNewFolder;

  /// No description provided for @singleDocumentCompressed.
  ///
  /// In fr, this message translates to:
  /// **'Document unique compresse'**
  String get singleDocumentCompressed;

  /// No description provided for @originalQualityPng.
  ///
  /// In fr, this message translates to:
  /// **'Qualite originale (PNG)'**
  String get originalQualityPng;

  /// No description provided for @pleaseWait.
  ///
  /// In fr, this message translates to:
  /// **'Un instant s\'il vous plait...'**
  String get pleaseWait;

  /// No description provided for @somethingWentWrong.
  ///
  /// In fr, this message translates to:
  /// **'Oups ! Quelque chose a mal tourne'**
  String get somethingWentWrong;

  /// No description provided for @editFolder.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le dossier'**
  String get editFolder;

  /// No description provided for @folderName.
  ///
  /// In fr, this message translates to:
  /// **'Nom du dossier...'**
  String get folderName;

  /// No description provided for @create.
  ///
  /// In fr, this message translates to:
  /// **'Creer'**
  String get create;

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Le nom ne peut pas etre vide'**
  String get nameCannotBeEmpty;

  /// No description provided for @createFolderToOrganize.
  ///
  /// In fr, this message translates to:
  /// **'Creez un dossier pour organiser vos documents'**
  String get createFolderToOrganize;

  /// No description provided for @createFolder.
  ///
  /// In fr, this message translates to:
  /// **'Creer un dossier'**
  String get createFolder;

  /// No description provided for @appIsLocked.
  ///
  /// In fr, this message translates to:
  /// **'Scanai est verrouille'**
  String get appIsLocked;

  /// No description provided for @authenticateToAccess.
  ///
  /// In fr, this message translates to:
  /// **'Authentifiez-vous pour acceder a vos documents securises.'**
  String get authenticateToAccess;

  /// No description provided for @unlock.
  ///
  /// In fr, this message translates to:
  /// **'Deverrouiller'**
  String get unlock;

  /// No description provided for @preparingImage.
  ///
  /// In fr, this message translates to:
  /// **'Preparation de l\'image...'**
  String get preparingImage;

  /// No description provided for @celebrationMessage1.
  ///
  /// In fr, this message translates to:
  /// **'Easy !'**
  String get celebrationMessage1;

  /// No description provided for @celebrationMessage2.
  ///
  /// In fr, this message translates to:
  /// **'On r\'commence ?!'**
  String get celebrationMessage2;

  /// No description provided for @celebrationMessage3.
  ///
  /// In fr, this message translates to:
  /// **'Encore besoin de moi ?'**
  String get celebrationMessage3;

  /// No description provided for @celebrationMessage4.
  ///
  /// In fr, this message translates to:
  /// **'Et hop, un de plus !'**
  String get celebrationMessage4;

  /// No description provided for @celebrationMessage5.
  ///
  /// In fr, this message translates to:
  /// **'Travail termine !'**
  String get celebrationMessage5;

  /// No description provided for @celebrationMessage6.
  ///
  /// In fr, this message translates to:
  /// **'Au suivant!'**
  String get celebrationMessage6;

  /// No description provided for @shareAppText.
  ///
  /// In fr, this message translates to:
  /// **'J\'utilise Scanai pour securiser et classer mes documents importants. C\'est rapide, securise et ultra-fluide !'**
  String get shareAppText;

  /// No description provided for @shareAppSubject.
  ///
  /// In fr, this message translates to:
  /// **'Scanai : Ton scanner de poche securise'**
  String get shareAppSubject;

  /// No description provided for @secureYourDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Securisez vos documents'**
  String get secureYourDocuments;

  /// No description provided for @savedLocally.
  ///
  /// In fr, this message translates to:
  /// **'Tout est sauvegarde localement'**
  String get savedLocally;

  /// No description provided for @documentsSecured.
  ///
  /// In fr, this message translates to:
  /// **'{count} documents securises'**
  String documentsSecured(int count);

  /// No description provided for @preferences.
  ///
  /// In fr, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @interface.
  ///
  /// In fr, this message translates to:
  /// **'Interface'**
  String get interface;

  /// No description provided for @textRecognition.
  ///
  /// In fr, this message translates to:
  /// **'Reconnaissance texte'**
  String get textRecognition;

  /// No description provided for @search.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher...'**
  String get search;

  /// No description provided for @nDocumentsLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count} documents'**
  String nDocumentsLabel(int count);

  /// No description provided for @nFoldersLabel.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 dossier} other{{count} dossiers}}'**
  String nFoldersLabel(int count);

  /// No description provided for @nDocs.
  ///
  /// In fr, this message translates to:
  /// **'{count} docs'**
  String nDocs(int count);

  /// No description provided for @foldersAndDocs.
  ///
  /// In fr, this message translates to:
  /// **'{folders, plural, =1{1 dossier} other{{folders} dossiers}}, {documents, plural, =1{1 document} other{{documents} documents}}'**
  String foldersAndDocs(int folders, int documents);

  /// No description provided for @scanner.
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get scanner;

  /// No description provided for @sortAndFilter.
  ///
  /// In fr, this message translates to:
  /// **'Trier et Filtrer'**
  String get sortAndFilter;

  /// No description provided for @clearAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get clearAll;

  /// No description provided for @sortBy.
  ///
  /// In fr, this message translates to:
  /// **'Trier par'**
  String get sortBy;

  /// No description provided for @quickFilters.
  ///
  /// In fr, this message translates to:
  /// **'Filtres rapides'**
  String get quickFilters;

  /// No description provided for @folder.
  ///
  /// In fr, this message translates to:
  /// **'Dossier'**
  String get folder;

  /// No description provided for @tags.
  ///
  /// In fr, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @apply.
  ///
  /// In fr, this message translates to:
  /// **'Appliquer'**
  String get apply;

  /// No description provided for @favoritesOnly.
  ///
  /// In fr, this message translates to:
  /// **'Favoris uniquement'**
  String get favoritesOnly;

  /// No description provided for @favoritesOnlyDescription.
  ///
  /// In fr, this message translates to:
  /// **'Afficher uniquement les documents marques comme favoris'**
  String get favoritesOnlyDescription;

  /// No description provided for @hasOcrText.
  ///
  /// In fr, this message translates to:
  /// **'Contient du texte OCR'**
  String get hasOcrText;

  /// No description provided for @hasOcrTextDescription.
  ///
  /// In fr, this message translates to:
  /// **'Afficher uniquement les documents avec du texte extrait'**
  String get hasOcrTextDescription;

  /// No description provided for @failedToLoadFolders.
  ///
  /// In fr, this message translates to:
  /// **'Echec du chargement des dossiers'**
  String get failedToLoadFolders;

  /// No description provided for @noFoldersYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun dossier cree'**
  String get noFoldersYet;

  /// No description provided for @allDocumentsFilter.
  ///
  /// In fr, this message translates to:
  /// **'Tous les documents'**
  String get allDocumentsFilter;

  /// No description provided for @failedToLoadTags.
  ///
  /// In fr, this message translates to:
  /// **'Echec du chargement des tags'**
  String get failedToLoadTags;

  /// No description provided for @noTagsYet.
  ///
  /// In fr, this message translates to:
  /// **'Aucun tag cree'**
  String get noTagsYet;

  /// No description provided for @initializingOcr.
  ///
  /// In fr, this message translates to:
  /// **'Initialisation OCR...'**
  String get initializingOcr;

  /// No description provided for @ocrSaved.
  ///
  /// In fr, this message translates to:
  /// **'Texte OCR sauvegarde dans le document'**
  String get ocrSaved;

  /// No description provided for @copiedWords.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 mot copie} other{{count} mots copies}} dans le presse-papiers'**
  String copiedWords(int count);

  /// No description provided for @failedToCopyText.
  ///
  /// In fr, this message translates to:
  /// **'Echec de la copie du texte'**
  String get failedToCopyText;

  /// No description provided for @searchInText.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans le texte...'**
  String get searchInText;

  /// No description provided for @matchesFound.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 resultat trouve} other{{count} resultats trouves}}'**
  String matchesFound(int count);

  /// No description provided for @done.
  ///
  /// In fr, this message translates to:
  /// **'Termine'**
  String get done;

  /// No description provided for @extractingTextProgress.
  ///
  /// In fr, this message translates to:
  /// **'Extraction du texte...'**
  String get extractingTextProgress;

  /// No description provided for @processingPage.
  ///
  /// In fr, this message translates to:
  /// **'Traitement de la page {current} sur {total}'**
  String processingPage(int current, int total);

  /// No description provided for @thisMayTakeAMoment.
  ///
  /// In fr, this message translates to:
  /// **'Cela peut prendre un moment'**
  String get thisMayTakeAMoment;

  /// No description provided for @scrollDisabledInSelectionMode.
  ///
  /// In fr, this message translates to:
  /// **'Mode selection actif - defilement desactive'**
  String get scrollDisabledInSelectionMode;

  /// No description provided for @words.
  ///
  /// In fr, this message translates to:
  /// **'Mots'**
  String get words;

  /// No description provided for @lines.
  ///
  /// In fr, this message translates to:
  /// **'Lignes'**
  String get lines;

  /// No description provided for @time.
  ///
  /// In fr, this message translates to:
  /// **'Temps'**
  String get time;

  /// No description provided for @noTextFound.
  ///
  /// In fr, this message translates to:
  /// **'Aucun texte trouve'**
  String get noTextFound;

  /// No description provided for @noTextFoundDescription.
  ///
  /// In fr, this message translates to:
  /// **'L\'image ne contient peut-etre pas de texte lisible,\nou la qualite est trop basse.'**
  String get noTextFoundDescription;

  /// No description provided for @tryAgain.
  ///
  /// In fr, this message translates to:
  /// **'Reessayer'**
  String get tryAgain;

  /// No description provided for @extractTextTitle.
  ///
  /// In fr, this message translates to:
  /// **'Extraire le texte'**
  String get extractTextTitle;

  /// No description provided for @extractTextDescription.
  ///
  /// In fr, this message translates to:
  /// **'Lancez l\'OCR pour extraire le texte\nde ce document.'**
  String get extractTextDescription;

  /// No description provided for @runOcr.
  ///
  /// In fr, this message translates to:
  /// **'Lancer OCR'**
  String get runOcr;

  /// No description provided for @allProcessingLocal.
  ///
  /// In fr, this message translates to:
  /// **'Tout le traitement se fait localement sur votre appareil'**
  String get allProcessingLocal;

  /// No description provided for @ocrOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options OCR'**
  String get ocrOptions;

  /// No description provided for @documentType.
  ///
  /// In fr, this message translates to:
  /// **'Type de document'**
  String get documentType;

  /// No description provided for @auto.
  ///
  /// In fr, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @singleColumn.
  ///
  /// In fr, this message translates to:
  /// **'Colonne unique'**
  String get singleColumn;

  /// No description provided for @singleBlock.
  ///
  /// In fr, this message translates to:
  /// **'Bloc unique'**
  String get singleBlock;

  /// No description provided for @sparseText.
  ///
  /// In fr, this message translates to:
  /// **'Texte epars'**
  String get sparseText;

  /// No description provided for @rerunOcr.
  ///
  /// In fr, this message translates to:
  /// **'Relancer OCR'**
  String get rerunOcr;

  /// No description provided for @saveToDocument.
  ///
  /// In fr, this message translates to:
  /// **'Sauvegarder dans le document'**
  String get saveToDocument;

  /// No description provided for @copySelection.
  ///
  /// In fr, this message translates to:
  /// **'Copier la selection'**
  String get copySelection;

  /// No description provided for @copySelectionTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Copier le texte selectionne'**
  String get copySelectionTooltip;

  /// No description provided for @searchInTextTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher dans le texte'**
  String get searchInTextTooltip;

  /// No description provided for @copyAllTextTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Copier tout le texte'**
  String get copyAllTextTooltip;

  /// No description provided for @shareTextTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Partager le texte'**
  String get shareTextTooltip;

  /// No description provided for @loadingDocuments.
  ///
  /// In fr, this message translates to:
  /// **'Chargement de vos documents...'**
  String get loadingDocuments;

  /// No description provided for @exportFailed.
  ///
  /// In fr, this message translates to:
  /// **'Echec de l\'exportation'**
  String get exportFailed;

  /// No description provided for @whatAreYouLookingFor.
  ///
  /// In fr, this message translates to:
  /// **'Que cherches-tu ?'**
  String get whatAreYouLookingFor;

  /// No description provided for @needHelp.
  ///
  /// In fr, this message translates to:
  /// **'Besoin d\'aide ?'**
  String get needHelp;

  /// No description provided for @clipboardSecurityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Securite du presse-papiers'**
  String get clipboardSecurityTitle;

  /// No description provided for @clipboardAutoClear.
  ///
  /// In fr, this message translates to:
  /// **'Effacement automatique'**
  String get clipboardAutoClear;

  /// No description provided for @clipboardAutoClearSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Efface apres copie'**
  String get clipboardAutoClearSubtitle;

  /// No description provided for @clipboardClearAfter.
  ///
  /// In fr, this message translates to:
  /// **'Effacer apres'**
  String get clipboardClearAfter;

  /// No description provided for @clipboardSensitiveDetection.
  ///
  /// In fr, this message translates to:
  /// **'Detection donnees sensibles'**
  String get clipboardSensitiveDetection;

  /// No description provided for @clipboardSensitiveDetectionSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Alertes pour donnees sensibles'**
  String get clipboardSensitiveDetectionSubtitle;

  /// No description provided for @clipboardTimeoutSeconds.
  ///
  /// In fr, this message translates to:
  /// **'{seconds}s'**
  String clipboardTimeoutSeconds(int seconds);

  /// No description provided for @sensitiveDataDetectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Donnees sensibles detectees'**
  String get sensitiveDataDetectedTitle;

  /// No description provided for @sensitiveDataWarningMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le texte que vous copiez peut contenir des informations sensibles accessibles par d\'autres applications.'**
  String get sensitiveDataWarningMessage;

  /// No description provided for @copyAnyway.
  ///
  /// In fr, this message translates to:
  /// **'Copier quand meme'**
  String get copyAnyway;

  /// No description provided for @detectedDataTypes.
  ///
  /// In fr, this message translates to:
  /// **'Detecte :'**
  String get detectedDataTypes;

  /// No description provided for @sensitiveTypeSsn.
  ///
  /// In fr, this message translates to:
  /// **'Numero de securite sociale'**
  String get sensitiveTypeSsn;

  /// No description provided for @sensitiveTypeCreditCard.
  ///
  /// In fr, this message translates to:
  /// **'numero de carte bancaire'**
  String get sensitiveTypeCreditCard;

  /// No description provided for @sensitiveTypeEmail.
  ///
  /// In fr, this message translates to:
  /// **'adresse e-mail'**
  String get sensitiveTypeEmail;

  /// No description provided for @sensitiveTypePhone.
  ///
  /// In fr, this message translates to:
  /// **'numero de telephone'**
  String get sensitiveTypePhone;

  /// No description provided for @sensitiveTypeAccount.
  ///
  /// In fr, this message translates to:
  /// **'numero de compte'**
  String get sensitiveTypeAccount;

  /// No description provided for @sensitiveTypePassword.
  ///
  /// In fr, this message translates to:
  /// **'mot de passe'**
  String get sensitiveTypePassword;

  /// No description provided for @clipboardWillClearIn.
  ///
  /// In fr, this message translates to:
  /// **'Presse-papiers efface dans {seconds}s'**
  String clipboardWillClearIn(int seconds);

  /// No description provided for @textCopiedToClipboard.
  ///
  /// In fr, this message translates to:
  /// **'Texte copie dans le presse-papiers'**
  String get textCopiedToClipboard;

  /// No description provided for @clipboardSecurityError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur securite presse-papiers : {error}'**
  String clipboardSecurityError(String error);

  /// No description provided for @licenses.
  ///
  /// In fr, this message translates to:
  /// **'Licences open source'**
  String get licenses;

  /// No description provided for @licensesSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Voir les licences des bibliotheques'**
  String get licensesSubtitle;

  /// No description provided for @localStorageWarningTitle.
  ///
  /// In fr, this message translates to:
  /// **'Stockage local uniquement'**
  String get localStorageWarningTitle;

  /// No description provided for @localStorageWarningMessage.
  ///
  /// In fr, this message translates to:
  /// **'Vos documents sont stockes sur votre appareil et chiffres. Si vous desinstallez l\'application, ils seront definitivement supprimes.\n\nPensez a exporter vos documents importants !'**
  String get localStorageWarningMessage;

  /// No description provided for @localStorageWarningButton.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai compris'**
  String get localStorageWarningButton;
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
