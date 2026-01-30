// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Scanai';

  @override
  String get settings => '설정';

  @override
  String get appearance => '외관';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get themeAuto => '자동';

  @override
  String get security => '잠금';

  @override
  String get enabled => '활성화';

  @override
  String get disabled => '비활성화';

  @override
  String get enableLockTitle => '잠금을 활성화하시겠습니까?';

  @override
  String get enableLockMessage => '지문으로 문서 접근을 보호하시겠습니까?';

  @override
  String get cancel => '취소';

  @override
  String get enable => '활성화';

  @override
  String get lockTimeoutImmediate => '즉시';

  @override
  String get lockTimeout1Min => '1분';

  @override
  String get lockTimeout5Min => '5분';

  @override
  String get lockTimeout30Min => '30분';

  @override
  String get about => '정보';

  @override
  String get developedWith => '개발자';

  @override
  String get securityDetails => '보안 상세';

  @override
  String get securityTitle => '보안';

  @override
  String get aes256 => 'AES-256';

  @override
  String get localEncryption => '로컬 암호화';

  @override
  String get zeroKnowledge => '제로 지식';

  @override
  String get exclusiveAccess => '독점 접근';

  @override
  String get offline => '오프라인';

  @override
  String get securedPercent => '100% 안전';

  @override
  String get settingsSpeechBubbleLine1 => '약간의';

  @override
  String get settingsSpeechBubbleLine2 => '조정?';

  @override
  String get dismiss => '닫기';

  @override
  String get myDocuments => '내 문서';

  @override
  String get scan => '스캔';

  @override
  String get share => '공유';

  @override
  String get delete => '삭제';

  @override
  String get rename => '이름 변경';

  @override
  String get noDocuments => '문서 없음';

  @override
  String get scanYourFirstDocument => '첫 번째 문서를 스캔하세요';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 문서',
      one: '1개의 문서',
      zero: '문서 없음',
    );
    return '$_temp0';
  }

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count페이지',
      one: '1페이지',
    );
    return '$_temp0';
  }

  @override
  String get greetingMorning => '좋은 아침입니다';

  @override
  String get greetingAfternoon => '안녕하세요';

  @override
  String get greetingEvening => '좋은 저녁입니다';

  @override
  String get randomMessage1 => 'PDF가 필요하세요?';

  @override
  String get randomMessage2 => '시작할까요?';

  @override
  String get randomMessage3 => '명령을 기다리고 있어요!';

  @override
  String get randomMessage4 => '가자!';

  @override
  String get ocrResults => 'OCR 결과';

  @override
  String get text => '텍스트';

  @override
  String get metadata => '메타데이터';

  @override
  String get copyText => '복사';

  @override
  String get textCopied => '텍스트가 복사되었습니다';

  @override
  String get noTextExtracted => '추출된 텍스트가 없습니다';

  @override
  String get language => '언어';

  @override
  String get processingTime => '처리 시간';

  @override
  String get wordCount => '단어 수';

  @override
  String get lineCount => '줄 수';

  @override
  String get confidence => '신뢰도';

  @override
  String get shareAs => '형식 선택';

  @override
  String get pdf => 'PDF';

  @override
  String get images => '이미지';

  @override
  String get ocrText => 'OCR 텍스트';

  @override
  String get appLanguage => '앱 언어';

  @override
  String get ocrLanguage => 'OCR 언어';

  @override
  String get systemLanguage => '시스템';

  @override
  String get french => '프랑스어';

  @override
  String get english => '영어';

  @override
  String get ocrLanguageAuto => '자동';

  @override
  String get ocrLanguageLatin => '라틴 문자 (EN, FR, ES...)';

  @override
  String get ocrLanguageChinese => '중국어';

  @override
  String get ocrLanguageJapanese => '일본어';

  @override
  String get ocrLanguageKorean => '한국어';

  @override
  String get ocrLanguageDevanagari => '데바나가리';

  @override
  String get scanDocument => '문서\n스캔';

  @override
  String get camera => '카메라';

  @override
  String get gallery => '갤러리';

  @override
  String get recentScans => '최근 스캔';

  @override
  String get allDocuments => '내 파일 보기';

  @override
  String get searchDocuments => '문서 검색';

  @override
  String get sortByDate => '날짜순';

  @override
  String get sortByName => '이름순';

  @override
  String get deleteConfirmTitle => '문서를 삭제하시겠습니까?';

  @override
  String get deleteConfirmMessage => '이 작업은 취소할 수 없습니다. 문서가 영구적으로 삭제됩니다.';

  @override
  String get errorOccurred => '오류가 발생했습니다';

  @override
  String get retry => '재시도';

  @override
  String get ok => '확인';

  @override
  String get yes => '예';

  @override
  String get no => '아니오';

  @override
  String get save => '저장';

  @override
  String get close => '닫기';

  @override
  String get extractText => '텍스트 추출';

  @override
  String get extractingText => '텍스트 추출 중...';

  @override
  String get documentName => '문서 이름';

  @override
  String get enterDocumentName => '문서 이름 입력';

  @override
  String get createdAt => '생성일';

  @override
  String get modifiedAt => '수정일';

  @override
  String get size => '크기';

  @override
  String get selectLanguage => '언어 선택';

  @override
  String get languageSettings => '언어 설정';

  @override
  String get openingScanner => '스캐너 열기...';

  @override
  String get savingDocument => '문서 저장 중...';

  @override
  String get launchingScanner => '스캐너 시작 중...';

  @override
  String documentExportedTo(String folder) {
    return '$folder에 내보내기 완료';
  }

  @override
  String get abandonScanTitle => '스캔을 취소하시겠습니까?';

  @override
  String get abandonScanMessage => '이 스캔을 취소하시겠습니까? 이 작업은 취소할 수 없습니다.';

  @override
  String get abandon => '취소';

  @override
  String get scanSuccessMessage => '완료되었습니다!';

  @override
  String get savePromptMessage => '저장할까요?';

  @override
  String get searchFolder => '폴더 검색...';

  @override
  String get newFolder => '새로 만들기';

  @override
  String get folderCreationFailed => '폴더 생성 실패';

  @override
  String get myDocs => '내 문서';

  @override
  String get saveHere => '여기에 저장';

  @override
  String get export => '내보내기';

  @override
  String get ocr => 'OCR';

  @override
  String get finish => '완료';

  @override
  String get move => '이동';

  @override
  String get decrypting => '복호화 중...';

  @override
  String get loading => '로딩 중...';

  @override
  String get unableToLoadImage => '이미지를 불러올 수 없습니다';

  @override
  String get noTextDetected => '문서에서 텍스트가 감지되지 않았습니다';

  @override
  String get noTextToShare => '공유할 텍스트가 없습니다';

  @override
  String get shareError => '공유 오류';

  @override
  String get folderCreationError => '폴더 생성 오류';

  @override
  String get favoriteUpdateFailed => '즐겨찾기 업데이트 실패';

  @override
  String get documentExported => '문서를 내보냈습니다';

  @override
  String documentsExported(int count) {
    return '$count개의 문서를 내보냈습니다';
  }

  @override
  String get title => '제목';

  @override
  String get pages => '페이지';

  @override
  String get format => '형식';

  @override
  String get justNow => '방금';

  @override
  String minutesAgo(int minutes) {
    return '$minutes분 전';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours시간 전';
  }

  @override
  String daysAgo(int days) {
    return '$days일 전';
  }

  @override
  String get lastUpdated => '마지막 업데이트';

  @override
  String folderSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 폴더 선택',
      one: '1개의 폴더 선택',
    );
    return '$_temp0';
  }

  @override
  String documentSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 문서 선택',
      one: '1개의 문서 선택',
    );
    return '$_temp0';
  }

  @override
  String get currentFolder => '현재 폴더';

  @override
  String noResultsFor(String query) {
    return '\"$query\"에 대한 결과 없음';
  }

  @override
  String get noFavorites => '즐겨찾기 없음';

  @override
  String get copy => '복사';

  @override
  String get selectAll => '모두 선택';

  @override
  String get selectionModeActive => '선택 모드';

  @override
  String get longPressToSelect => '길게 눌러서 선택';

  @override
  String get selectTextEasily => '쉽게 텍스트 선택';

  @override
  String get selection => '선택';

  @override
  String wordSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 단어 선택',
      one: '1개의 단어 선택',
    );
    return '$_temp0';
  }

  @override
  String get renameDocument => '문서 이름 변경';

  @override
  String get newTitle => '새 제목...';

  @override
  String get saveUnder => '저장 위치...';

  @override
  String moveDocuments(int count) {
    return '$count개의 문서 이동';
  }

  @override
  String get chooseDestinationFolder => '대상 폴더 선택';

  @override
  String get rootFolder => '루트 (폴더 없음)';

  @override
  String get createNewFolder => '새 폴더 만들기';

  @override
  String get singleDocumentCompressed => '단일 압축 문서';

  @override
  String get originalQualityPng => '원본 화질 (PNG)';

  @override
  String get pleaseWait => '잠시만 기다려주세요...';

  @override
  String get somethingWentWrong => '문제가 발생했습니다';

  @override
  String get editFolder => '폴더 편집';

  @override
  String get folderName => '폴더 이름...';

  @override
  String get create => '만들기';

  @override
  String get nameCannotBeEmpty => '이름을 입력해주세요';

  @override
  String get createFolderToOrganize => '폴더를 만들어 문서를 정리하세요';

  @override
  String get createFolder => '폴더 만들기';

  @override
  String get appIsLocked => 'Scanai가 잠겨 있습니다';

  @override
  String get authenticateToAccess => '인증하여 문서에 접근하세요.';

  @override
  String get unlock => '잠금 해제';

  @override
  String get preparingImage => '이미지 준비 중...';

  @override
  String get celebrationMessage1 => '쉽죠!';

  @override
  String get celebrationMessage2 => '또?!';

  @override
  String get celebrationMessage3 => '또 필요하세요?';

  @override
  String get celebrationMessage4 => '하나 더 완료!';

  @override
  String get celebrationMessage5 => '작업 완료!';

  @override
  String get celebrationMessage6 => '다음!';

  @override
  String get shareAppText => 'Scanai로 중요한 문서를 안전하게 정리하고 있어요. 빠르고, 안전하고, 부드러워요!';

  @override
  String get shareAppSubject => 'Scanai: 당신의 안전한 포켓 스캐너';

  @override
  String get secureYourDocuments => '문서 보호';

  @override
  String get savedLocally => '모두 로컬에 저장';

  @override
  String documentsSecured(int count) {
    return '$count개의 문서 보호됨';
  }

  @override
  String get preferences => '환경설정';

  @override
  String get interface => '인터페이스';

  @override
  String get textRecognition => '텍스트 인식';

  @override
  String get search => '검색...';

  @override
  String nDocumentsLabel(int count) {
    return '$count개의 문서';
  }

  @override
  String nFoldersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 폴더',
      one: '1개의 폴더',
    );
    return '$_temp0';
  }

  @override
  String nDocs(int count) {
    return '$count개';
  }

  @override
  String foldersAndDocs(int folders, int documents) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders개의 폴더',
      one: '1개의 폴더',
    );
    String _temp1 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents개의 문서',
      one: '1개의 문서',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get scanner => '스캔';

  @override
  String get sortAndFilter => '정렬 및 필터';

  @override
  String get clearAll => '모두 지우기';

  @override
  String get sortBy => '정렬 기준';

  @override
  String get quickFilters => '빠른 필터';

  @override
  String get folder => '폴더';

  @override
  String get tags => '태그';

  @override
  String get apply => '적용';

  @override
  String get favoritesOnly => '즐겨찾기만';

  @override
  String get favoritesOnlyDescription => '즐겨찾기 문서만 표시';

  @override
  String get hasOcrText => 'OCR 텍스트 있음';

  @override
  String get hasOcrTextDescription => '텍스트가 추출된 문서만 표시';

  @override
  String get failedToLoadFolders => '폴더 로드 실패';

  @override
  String get noFoldersYet => '폴더가 아직 없습니다';

  @override
  String get allDocumentsFilter => '모든 문서';

  @override
  String get failedToLoadTags => '태그 로드 실패';

  @override
  String get noTagsYet => '태그가 아직 없습니다';

  @override
  String get initializingOcr => 'OCR 초기화 중...';

  @override
  String get ocrSaved => 'OCR 텍스트가 문서에 저장되었습니다';

  @override
  String copiedWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 단어가 복사되었습니다',
      one: '1개의 단어가 복사되었습니다',
    );
    return '$_temp0';
  }

  @override
  String get failedToCopyText => '텍스트 복사 실패';

  @override
  String get searchInText => '텍스트에서 검색...';

  @override
  String matchesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개의 일치',
      one: '1개의 일치',
    );
    return '$_temp0';
  }

  @override
  String get done => '완료';

  @override
  String get extractingTextProgress => '텍스트 추출 중...';

  @override
  String processingPage(int current, int total) {
    return '$total페이지 중 $current페이지 처리 중';
  }

  @override
  String get thisMayTakeAMoment => '잠시 기다려 주세요';

  @override
  String get scrollDisabledInSelectionMode => '선택 모드 - 스크롤 비활성화';

  @override
  String get words => '단어';

  @override
  String get lines => '줄';

  @override
  String get time => '시간';

  @override
  String get noTextFound => '텍스트를 찾을 수 없습니다';

  @override
  String get noTextFoundDescription =>
      '이미지에 읽을 수 있는 텍스트가 없거나\n화질이 너무 낮을 수 있습니다.';

  @override
  String get tryAgain => '다시 시도';

  @override
  String get extractTextTitle => '텍스트 추출';

  @override
  String get extractTextDescription => 'OCR을 실행하여 이 문서에서\n읽을 수 있는 텍스트를 추출합니다.';

  @override
  String get runOcr => 'OCR 실행';

  @override
  String get allProcessingLocal => '모든 처리는 기기에서 로컬로 수행됩니다';

  @override
  String get ocrOptions => 'OCR 옵션';

  @override
  String get documentType => '문서 유형';

  @override
  String get auto => '자동';

  @override
  String get singleColumn => '단일 열';

  @override
  String get singleBlock => '단일 블록';

  @override
  String get sparseText => '흩어진 텍스트';

  @override
  String get rerunOcr => 'OCR 재실행';

  @override
  String get saveToDocument => '문서에 저장';

  @override
  String get copySelection => '선택 복사';

  @override
  String get copySelectionTooltip => '선택한 텍스트를 클립보드에 복사';

  @override
  String get searchInTextTooltip => '텍스트에서 검색';

  @override
  String get copyAllTextTooltip => '모든 텍스트 복사';

  @override
  String get shareTextTooltip => '텍스트 공유';

  @override
  String get loadingDocuments => '문서 로딩 중...';

  @override
  String get exportFailed => '내보내기 실패';

  @override
  String get whatAreYouLookingFor => '무엇을 찾고 계세요?';

  @override
  String get needHelp => '도움이 필요하세요?';

  @override
  String get licenses => '오픈 소스 라이선스';

  @override
  String get licensesSubtitle => '라이브러리 라이선스 보기';

  @override
  String get localStorageWarningTitle => '로컬 저장소만';

  @override
  String get localStorageWarningMessage =>
      '문서는 기기에 저장되며 암호화됩니다. 앱을 삭제하면 영구적으로 삭제됩니다.\n\n중요한 문서는 꼭 내보내기하세요!';

  @override
  String get localStorageWarningButton => '알겠습니다';

  @override
  String get deviceSecurityWarningTitle => '보안 경고';

  @override
  String get deviceSecurityWarningMessage => '기기가 루팅되거나 탈옥된 것 같습니다.';

  @override
  String get deviceSecurityWarningDetails =>
      '수정된 기기에서는 암호화, 보안 저장소, 생체 인증과 같은 보안 기능이 손상될 수 있습니다. 문서가 위험에 처할 수 있습니다.\n\n앱은 계속 작동하지만, 보안이 저하되었음을 유의하세요.';

  @override
  String get deviceSecurityContinue => '이해했습니다';

  @override
  String get showSecurityWarnings => '보안 경고 표시';

  @override
  String get showSecurityWarningsDescription => '루팅되거나 탈옥된 기기에서 경고 표시';

  @override
  String get premiumTitle => '프리미엄 평생';

  @override
  String get premiumSubtitle => '한 번 구매로 모든 기능 잠금 해제';

  @override
  String get premiumUnlockPotential => '내 잠재력을 해제해주세요!';

  @override
  String get premiumNoScansLeft => '무료 스캔을 모두 사용했습니다!';

  @override
  String get premiumOcrRequired => 'OCR은 프리미엄 회원 전용입니다';

  @override
  String get premiumExportRequired => 'PDF 내보내기는 프리미엄 회원 전용입니다';

  @override
  String get premiumFeatureUnlimitedScans => '무제한 스캔';

  @override
  String get premiumFeatureMultipage => '다중 페이지 문서 (최대 100페이지)';

  @override
  String get premiumFeaturePdfExport => 'PDF 내보내기';

  @override
  String get premiumFeatureSharing => '문서 공유';

  @override
  String get premiumFeatureOcr => '텍스트 추출 (OCR)';

  @override
  String premiumPurchaseButton(String price) {
    return '$price으로 잠금 해제';
  }

  @override
  String get premiumRestorePurchases => '구매 복원';

  @override
  String get premiumLater => '나중에';

  @override
  String get premiumBadgeLabel => '프리미엄';

  @override
  String get premiumStatusPremium => '프리미엄';

  @override
  String get premiumStatusPremiumSubtitle => '모든 기능 잠금 해제됨';

  @override
  String get premiumStatusFree => '무료';

  @override
  String premiumStatusFreeSubtitle(int remaining, int total) {
    return '$total개 중 $remaining개 스캔 남음';
  }

  @override
  String get premiumScansRemaining => '남은 스캔';

  @override
  String get premiumUpgradeButton => '프리미엄으로 업그레이드';

  @override
  String get premiumDebugToggleTitle => '프리미엄 시뮬레이션 (디버그)';

  @override
  String get premiumDebugToggleSubtitle => '테스트용 모든 프리미엄 기능 활성화';

  @override
  String get premiumDebugResetScans => '스캔 카운터 리셋';

  @override
  String get premiumDebugResetSuccess => '스캔 카운터가 리셋되었습니다';

  @override
  String get premiumBlockedNoScans => '무료 스캔을 모두 사용했습니다';

  @override
  String get premiumRequiredTitle => '프리미엄 필요';

  @override
  String get premiumRequiredMessage => '이 기능은 프리미엄 구독이 필요합니다';

  @override
  String get premiumFeatureLockedOcr => 'OCR 텍스트 추출은 프리미엄 기능입니다';

  @override
  String get premiumFeatureLockedExport => 'PDF 내보내기는 프리미엄 기능입니다';

  @override
  String get premiumFeatureLockedShare => '문서 공유는 프리미엄 기능입니다';

  @override
  String get premiumFeatureLockedMultipage => '다중 페이지 스캔은 프리미엄 기능입니다';
}
