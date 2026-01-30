// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Scanai';

  @override
  String get settings => '設定';

  @override
  String get appearance => '外観';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeAuto => '自動';

  @override
  String get security => 'ロック';

  @override
  String get enabled => '有効';

  @override
  String get disabled => '無効';

  @override
  String get enableLockTitle => 'ロックを有効にしますか？';

  @override
  String get enableLockMessage => '指紋認証でドキュメントへのアクセスを保護しますか？';

  @override
  String get cancel => 'キャンセル';

  @override
  String get enable => '有効にする';

  @override
  String get lockTimeoutImmediate => '即時';

  @override
  String get lockTimeout1Min => '1分';

  @override
  String get lockTimeout5Min => '5分';

  @override
  String get lockTimeout30Min => '30分';

  @override
  String get about => '情報';

  @override
  String get developedWith => '開発者';

  @override
  String get securityDetails => 'セキュリティ詳細';

  @override
  String get securityTitle => 'セキュリティ';

  @override
  String get aes256 => 'AES-256';

  @override
  String get localEncryption => 'ローカル暗号化';

  @override
  String get zeroKnowledge => 'ゼロ知識';

  @override
  String get exclusiveAccess => '排他的アクセス';

  @override
  String get offline => 'オフライン';

  @override
  String get securedPercent => '100%安全';

  @override
  String get settingsSpeechBubbleLine1 => 'ちょっと';

  @override
  String get settingsSpeechBubbleLine2 => '調整する？';

  @override
  String get dismiss => '閉じる';

  @override
  String get myDocuments => 'マイドキュメント';

  @override
  String get scan => 'スキャン';

  @override
  String get share => '共有';

  @override
  String get delete => '削除';

  @override
  String get rename => '名前変更';

  @override
  String get noDocuments => 'ドキュメントなし';

  @override
  String get scanYourFirstDocument => '最初のドキュメントをスキャン';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のドキュメント',
      one: '1件のドキュメント',
      zero: 'ドキュメントなし',
    );
    return '$_temp0';
  }

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countページ',
      one: '1ページ',
    );
    return '$_temp0';
  }

  @override
  String get greetingMorning => 'おはようございます';

  @override
  String get greetingAfternoon => 'こんにちは';

  @override
  String get greetingEvening => 'こんばんは';

  @override
  String get randomMessage1 => 'PDFが必要？';

  @override
  String get randomMessage2 => '行きましょう？';

  @override
  String get randomMessage3 => 'ご指示をお待ちしています！';

  @override
  String get randomMessage4 => 'さあ行こう！';

  @override
  String get ocrResults => 'OCR結果';

  @override
  String get text => 'テキスト';

  @override
  String get metadata => 'メタデータ';

  @override
  String get copyText => 'コピー';

  @override
  String get textCopied => 'テキストをコピーしました';

  @override
  String get noTextExtracted => 'テキストが抽出されませんでした';

  @override
  String get language => '言語';

  @override
  String get processingTime => '処理時間';

  @override
  String get wordCount => '単語数';

  @override
  String get lineCount => '行数';

  @override
  String get confidence => '信頼度';

  @override
  String get shareAs => '形式を選択';

  @override
  String get pdf => 'PDF';

  @override
  String get images => '画像';

  @override
  String get ocrText => 'OCRテキスト';

  @override
  String get appLanguage => 'アプリの言語';

  @override
  String get ocrLanguage => 'OCR言語';

  @override
  String get systemLanguage => 'システム';

  @override
  String get french => 'フランス語';

  @override
  String get english => '英語';

  @override
  String get ocrLanguageAuto => '自動';

  @override
  String get ocrLanguageLatin => 'ラテン文字 (EN, FR, ES...)';

  @override
  String get ocrLanguageChinese => '中国語';

  @override
  String get ocrLanguageJapanese => '日本語';

  @override
  String get ocrLanguageKorean => '韓国語';

  @override
  String get ocrLanguageDevanagari => 'デーバナーガリー';

  @override
  String get scanDocument => 'ドキュメントを\nスキャン';

  @override
  String get camera => 'カメラ';

  @override
  String get gallery => 'ギャラリー';

  @override
  String get recentScans => '最近のスキャン';

  @override
  String get allDocuments => 'ファイルを表示';

  @override
  String get searchDocuments => 'ドキュメントを検索';

  @override
  String get sortByDate => '日付順';

  @override
  String get sortByName => '名前順';

  @override
  String get deleteConfirmTitle => 'ドキュメントを削除しますか？';

  @override
  String get deleteConfirmMessage => 'この操作は取り消せません。ドキュメントは完全に削除されます。';

  @override
  String get errorOccurred => 'エラーが発生しました';

  @override
  String get retry => '再試行';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'はい';

  @override
  String get no => 'いいえ';

  @override
  String get save => '保存';

  @override
  String get close => '閉じる';

  @override
  String get extractText => 'テキスト抽出';

  @override
  String get extractingText => 'テキストを抽出中...';

  @override
  String get documentName => 'ドキュメント名';

  @override
  String get enterDocumentName => 'ドキュメント名を入力';

  @override
  String get createdAt => '作成日';

  @override
  String get modifiedAt => '更新日';

  @override
  String get size => 'サイズ';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get languageSettings => '言語設定';

  @override
  String get openingScanner => 'スキャナーを起動中...';

  @override
  String get savingDocument => 'ドキュメントを保存中...';

  @override
  String get launchingScanner => 'スキャナーを起動中...';

  @override
  String documentExportedTo(String folder) {
    return '$folderにエクスポートしました';
  }

  @override
  String get abandonScanTitle => 'スキャンを中止しますか？';

  @override
  String get abandonScanMessage => 'このスキャンを中止してもよろしいですか？この操作は取り消せません。';

  @override
  String get abandon => '中止';

  @override
  String get scanSuccessMessage => '完了しました！';

  @override
  String get savePromptMessage => '保存しますか？';

  @override
  String get searchFolder => 'フォルダを検索...';

  @override
  String get newFolder => '新規';

  @override
  String get folderCreationFailed => 'フォルダの作成に失敗しました';

  @override
  String get myDocs => 'マイドキュメント';

  @override
  String get saveHere => 'ここに保存';

  @override
  String get export => 'エクスポート';

  @override
  String get ocr => 'OCR';

  @override
  String get finish => '完了';

  @override
  String get move => '移動';

  @override
  String get decrypting => '復号化中...';

  @override
  String get loading => '読み込み中...';

  @override
  String get unableToLoadImage => '画像を読み込めません';

  @override
  String get noTextDetected => 'ドキュメントにテキストが検出されませんでした';

  @override
  String get noTextToShare => '共有するテキストがありません';

  @override
  String get shareError => '共有エラー';

  @override
  String get folderCreationError => 'フォルダ作成エラー';

  @override
  String get favoriteUpdateFailed => 'お気に入りの更新に失敗しました';

  @override
  String get documentExported => 'ドキュメントをエクスポートしました';

  @override
  String documentsExported(int count) {
    return '$count件のドキュメントをエクスポートしました';
  }

  @override
  String get title => 'タイトル';

  @override
  String get pages => 'ページ';

  @override
  String get format => '形式';

  @override
  String get justNow => 'たった今';

  @override
  String minutesAgo(int minutes) {
    return '$minutes分前';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours時間前';
  }

  @override
  String daysAgo(int days) {
    return '$days日前';
  }

  @override
  String get lastUpdated => '最終更新';

  @override
  String folderSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countつのフォルダを選択',
      one: '1つのフォルダを選択',
    );
    return '$_temp0';
  }

  @override
  String documentSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のドキュメントを選択',
      one: '1件のドキュメントを選択',
    );
    return '$_temp0';
  }

  @override
  String get currentFolder => '現在のフォルダ';

  @override
  String noResultsFor(String query) {
    return '「$query」の結果がありません';
  }

  @override
  String get noFavorites => 'お気に入りなし';

  @override
  String get copy => 'コピー';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get selectionModeActive => '選択モード';

  @override
  String get longPressToSelect => '長押しで選択';

  @override
  String get selectTextEasily => '簡単にテキストを選択';

  @override
  String get selection => '選択';

  @override
  String wordSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count単語を選択',
      one: '1単語を選択',
    );
    return '$_temp0';
  }

  @override
  String get renameDocument => 'ドキュメント名を変更';

  @override
  String get newTitle => '新しいタイトル...';

  @override
  String get saveUnder => '保存先...';

  @override
  String moveDocuments(int count) {
    return '$count件のドキュメントを移動';
  }

  @override
  String get chooseDestinationFolder => '保存先フォルダを選択';

  @override
  String get rootFolder => 'ルート（フォルダなし）';

  @override
  String get createNewFolder => '新しいフォルダを作成';

  @override
  String get singleDocumentCompressed => '単一の圧縮ドキュメント';

  @override
  String get originalQualityPng => 'オリジナル画質 (PNG)';

  @override
  String get pleaseWait => 'お待ちください...';

  @override
  String get somethingWentWrong => 'エラーが発生しました';

  @override
  String get editFolder => 'フォルダを編集';

  @override
  String get folderName => 'フォルダ名...';

  @override
  String get create => '作成';

  @override
  String get nameCannotBeEmpty => '名前を入力してください';

  @override
  String get createFolderToOrganize => 'フォルダを作成してドキュメントを整理';

  @override
  String get createFolder => 'フォルダを作成';

  @override
  String get appIsLocked => 'Scanaiはロックされています';

  @override
  String get authenticateToAccess => '認証してドキュメントにアクセスしてください。';

  @override
  String get unlock => 'ロック解除';

  @override
  String get preparingImage => '画像を準備中...';

  @override
  String get celebrationMessage1 => '簡単！';

  @override
  String get celebrationMessage2 => 'また？！';

  @override
  String get celebrationMessage3 => 'また必要ですか？';

  @override
  String get celebrationMessage4 => 'もう1つ完了！';

  @override
  String get celebrationMessage5 => '作業完了！';

  @override
  String get celebrationMessage6 => '次へ！';

  @override
  String get shareAppText => 'Scanaiで重要なドキュメントを安全に整理しています。高速、安全、スムーズ！';

  @override
  String get shareAppSubject => 'Scanai: あなたの安全なポケットスキャナー';

  @override
  String get secureYourDocuments => 'ドキュメントを保護';

  @override
  String get savedLocally => 'すべてローカルに保存';

  @override
  String documentsSecured(int count) {
    return '$count件のドキュメントを保護';
  }

  @override
  String get preferences => '設定';

  @override
  String get interface => 'インターフェース';

  @override
  String get textRecognition => 'テキスト認識';

  @override
  String get search => '検索...';

  @override
  String nDocumentsLabel(int count) {
    return '$count件のドキュメント';
  }

  @override
  String nFoldersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countつのフォルダ',
      one: '1つのフォルダ',
    );
    return '$_temp0';
  }

  @override
  String nDocs(int count) {
    return '$count件';
  }

  @override
  String foldersAndDocs(int folders, int documents) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$foldersつのフォルダ',
      one: '1つのフォルダ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents件のドキュメント',
      one: '1件のドキュメント',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get scanner => 'スキャン';

  @override
  String get sortAndFilter => '並べ替えとフィルター';

  @override
  String get clearAll => 'すべてクリア';

  @override
  String get sortBy => '並べ替え';

  @override
  String get quickFilters => 'クイックフィルター';

  @override
  String get folder => 'フォルダ';

  @override
  String get tags => 'タグ';

  @override
  String get apply => '適用';

  @override
  String get favoritesOnly => 'お気に入りのみ';

  @override
  String get favoritesOnlyDescription => 'お気に入りのドキュメントのみ表示';

  @override
  String get hasOcrText => 'OCRテキストあり';

  @override
  String get hasOcrTextDescription => 'テキストが抽出されたドキュメントのみ表示';

  @override
  String get failedToLoadFolders => 'フォルダの読み込みに失敗しました';

  @override
  String get noFoldersYet => 'フォルダがまだありません';

  @override
  String get allDocumentsFilter => 'すべてのドキュメント';

  @override
  String get failedToLoadTags => 'タグの読み込みに失敗しました';

  @override
  String get noTagsYet => 'タグがまだありません';

  @override
  String get initializingOcr => 'OCRを初期化中...';

  @override
  String get ocrSaved => 'OCRテキストをドキュメントに保存しました';

  @override
  String copiedWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count単語をコピーしました',
      one: '1単語をコピーしました',
    );
    return '$_temp0';
  }

  @override
  String get failedToCopyText => 'テキストのコピーに失敗しました';

  @override
  String get searchInText => 'テキスト内を検索...';

  @override
  String matchesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の一致',
      one: '1件の一致',
    );
    return '$_temp0';
  }

  @override
  String get done => '完了';

  @override
  String get extractingTextProgress => 'テキストを抽出中...';

  @override
  String processingPage(int current, int total) {
    return '$totalページ中$currentページを処理中';
  }

  @override
  String get thisMayTakeAMoment => '少々お待ちください';

  @override
  String get scrollDisabledInSelectionMode => '選択モード中 - スクロール無効';

  @override
  String get words => '単語';

  @override
  String get lines => '行';

  @override
  String get time => '時間';

  @override
  String get noTextFound => 'テキストが見つかりません';

  @override
  String get noTextFoundDescription => '画像に読み取り可能なテキストがないか、\n画質が低い可能性があります。';

  @override
  String get tryAgain => '再試行';

  @override
  String get extractTextTitle => 'テキスト抽出';

  @override
  String get extractTextDescription => 'OCRを実行してこのドキュメントから\n読み取り可能なテキストを抽出します。';

  @override
  String get runOcr => 'OCRを実行';

  @override
  String get allProcessingLocal => 'すべての処理はデバイス上でローカルに行われます';

  @override
  String get ocrOptions => 'OCRオプション';

  @override
  String get documentType => 'ドキュメントタイプ';

  @override
  String get auto => '自動';

  @override
  String get singleColumn => '単一列';

  @override
  String get singleBlock => '単一ブロック';

  @override
  String get sparseText => '散在テキスト';

  @override
  String get rerunOcr => 'OCRを再実行';

  @override
  String get saveToDocument => 'ドキュメントに保存';

  @override
  String get copySelection => '選択をコピー';

  @override
  String get copySelectionTooltip => '選択したテキストをクリップボードにコピー';

  @override
  String get searchInTextTooltip => 'テキスト内を検索';

  @override
  String get copyAllTextTooltip => 'すべてのテキストをコピー';

  @override
  String get shareTextTooltip => 'テキストを共有';

  @override
  String get loadingDocuments => 'ドキュメントを読み込み中...';

  @override
  String get exportFailed => 'エクスポートに失敗しました';

  @override
  String get whatAreYouLookingFor => '何をお探しですか？';

  @override
  String get needHelp => 'ヘルプが必要ですか？';

  @override
  String get licenses => 'オープンソースライセンス';

  @override
  String get licensesSubtitle => 'ライブラリライセンスを表示';

  @override
  String get localStorageWarningTitle => 'ローカルストレージのみ';

  @override
  String get localStorageWarningMessage =>
      'ドキュメントはデバイスに保存され、暗号化されています。アプリをアンインストールすると、永久に削除されます。\n\n重要なドキュメントは必ずエクスポートしてください！';

  @override
  String get localStorageWarningButton => '了解';

  @override
  String get deviceSecurityWarningTitle => 'セキュリティ警告';

  @override
  String get deviceSecurityWarningMessage =>
      'お使いのデバイスはルート化またはジェイルブレイクされているようです。';

  @override
  String get deviceSecurityWarningDetails =>
      '変更されたデバイスでは、暗号化、セキュアストレージ、生体認証などのセキュリティ機能が損なわれる可能性があります。ドキュメントが危険にさらされる可能性があります。\n\nアプリは引き続き機能しますが、セキュリティが低下していることにご注意ください。';

  @override
  String get deviceSecurityContinue => '理解しました';

  @override
  String get showSecurityWarnings => 'セキュリティ警告を表示';

  @override
  String get showSecurityWarningsDescription => 'ルート化またはジェイルブレイクされたデバイスで警告を表示';

  @override
  String get premiumTitle => 'プレミアム永久版';

  @override
  String get premiumSubtitle => '一度の購入ですべての機能をアンロック';

  @override
  String get premiumUnlockPotential => '私のポテンシャルを解放！';

  @override
  String get premiumNoScansLeft => '無料スキャンを使い切りました！';

  @override
  String get premiumOcrRequired => 'OCRはプレミアム会員限定です';

  @override
  String get premiumExportRequired => 'PDFエクスポートはプレミアム会員限定です';

  @override
  String get premiumFeatureUnlimitedScans => '無制限スキャン';

  @override
  String get premiumFeatureMultipage => '複数ページドキュメント（最大100ページ）';

  @override
  String get premiumFeaturePdfExport => 'PDFエクスポート';

  @override
  String get premiumFeatureSharing => 'ドキュメント共有';

  @override
  String get premiumFeatureOcr => 'テキスト抽出（OCR）';

  @override
  String premiumPurchaseButton(String price) {
    return '$priceでアンロック';
  }

  @override
  String get premiumRestorePurchases => '購入を復元';

  @override
  String get premiumLater => '後で';

  @override
  String get premiumBadgeLabel => 'プレミアム';

  @override
  String get premiumStatusPremium => 'プレミアム';

  @override
  String get premiumStatusPremiumSubtitle => 'すべての機能がアンロック済み';

  @override
  String get premiumStatusFree => '無料';

  @override
  String premiumStatusFreeSubtitle(int remaining, int total) {
    return '残り$remaining/$totalスキャン';
  }

  @override
  String get premiumScansRemaining => '残りスキャン数';

  @override
  String get premiumUpgradeButton => 'プレミアムにアップグレード';

  @override
  String get premiumDebugToggleTitle => 'プレミアムをシミュレート（デバッグ）';

  @override
  String get premiumDebugToggleSubtitle => 'テスト用にすべてのプレミアム機能を有効化';

  @override
  String get premiumDebugResetScans => 'スキャンカウンターをリセット';

  @override
  String get premiumDebugResetSuccess => 'スキャンカウンターをリセットしました';

  @override
  String get premiumBlockedNoScans => '無料スキャンをすべて使い切りました';

  @override
  String get premiumRequiredTitle => 'プレミアムが必要です';

  @override
  String get premiumRequiredMessage => 'この機能にはプレミアムサブスクリプションが必要です';

  @override
  String get premiumFeatureLockedOcr => 'OCRテキスト抽出はプレミアム機能です';

  @override
  String get premiumFeatureLockedExport => 'PDFエクスポートはプレミアム機能です';

  @override
  String get premiumFeatureLockedShare => 'ドキュメント共有はプレミアム機能です';

  @override
  String get premiumFeatureLockedMultipage => '複数ページスキャンはプレミアム機能です';
}
