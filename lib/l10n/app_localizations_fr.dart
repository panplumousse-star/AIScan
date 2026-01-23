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
  String get randomMessage1 => 'Pret a numeriser ?';

  @override
  String get randomMessage2 => 'Vos documents en securite';

  @override
  String get randomMessage3 => 'Scanner, c\'est preserver';

  @override
  String get randomMessage4 => 'Tout est sous controle';

  @override
  String get randomMessage5 => 'La simplicite avant tout';

  @override
  String get ocrResults => 'Resultats OCR';

  @override
  String get text => 'Texte';

  @override
  String get metadata => 'Metadonnees';

  @override
  String get copyText => 'Copier le texte';

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
  String get shareAs => 'Partager comme';

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
  String get scanDocument => 'Scanner un document';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Galerie';

  @override
  String get recentScans => 'Scans recents';

  @override
  String get allDocuments => 'Tous les documents';

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
}
