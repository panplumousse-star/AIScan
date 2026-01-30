// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Scanai';

  @override
  String get settings => '设置';

  @override
  String get appearance => '外观';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeAuto => '自动';

  @override
  String get security => '锁定';

  @override
  String get enabled => '已启用';

  @override
  String get disabled => '已禁用';

  @override
  String get enableLockTitle => '启用锁定？';

  @override
  String get enableLockMessage => '是否使用指纹保护您的文档访问？';

  @override
  String get cancel => '取消';

  @override
  String get enable => '启用';

  @override
  String get lockTimeoutImmediate => '立即';

  @override
  String get lockTimeout1Min => '1分钟';

  @override
  String get lockTimeout5Min => '5分钟';

  @override
  String get lockTimeout30Min => '30分钟';

  @override
  String get about => '关于';

  @override
  String get developedWith => '开发者';

  @override
  String get securityDetails => '安全详情';

  @override
  String get securityTitle => '安全';

  @override
  String get aes256 => 'AES-256';

  @override
  String get localEncryption => '本地加密';

  @override
  String get zeroKnowledge => '零知识';

  @override
  String get exclusiveAccess => '独占访问';

  @override
  String get offline => '离线';

  @override
  String get securedPercent => '100%安全';

  @override
  String get settingsSpeechBubbleLine1 => '来点';

  @override
  String get settingsSpeechBubbleLine2 => '调整？';

  @override
  String get dismiss => '关闭';

  @override
  String get myDocuments => '我的文档';

  @override
  String get scan => '扫描';

  @override
  String get share => '分享';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get noDocuments => '无文档';

  @override
  String get scanYourFirstDocument => '扫描您的第一个文档';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个文档',
      one: '1个文档',
      zero: '无文档',
    );
    return '$_temp0';
  }

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count页',
      one: '1页',
    );
    return '$_temp0';
  }

  @override
  String get greetingMorning => '早上好';

  @override
  String get greetingAfternoon => '下午好';

  @override
  String get greetingEvening => '晚上好';

  @override
  String get randomMessage1 => '需要PDF吗？';

  @override
  String get randomMessage2 => '开始吧？';

  @override
  String get randomMessage3 => '等待您的指令！';

  @override
  String get randomMessage4 => '走吧！';

  @override
  String get ocrResults => 'OCR结果';

  @override
  String get text => '文本';

  @override
  String get metadata => '元数据';

  @override
  String get copyText => '复制';

  @override
  String get textCopied => '文本已复制';

  @override
  String get noTextExtracted => '未提取到文本';

  @override
  String get language => '语言';

  @override
  String get processingTime => '处理时间';

  @override
  String get wordCount => '字数';

  @override
  String get lineCount => '行数';

  @override
  String get confidence => '置信度';

  @override
  String get shareAs => '分享为';

  @override
  String get pdf => 'PDF';

  @override
  String get images => '图片';

  @override
  String get ocrText => 'OCR文本';

  @override
  String get appLanguage => '应用语言';

  @override
  String get ocrLanguage => 'OCR语言';

  @override
  String get systemLanguage => '系统';

  @override
  String get french => '法语';

  @override
  String get english => '英语';

  @override
  String get ocrLanguageAuto => '自动';

  @override
  String get ocrLanguageLatin => '拉丁文字 (EN, FR, ES...)';

  @override
  String get ocrLanguageChinese => '中文';

  @override
  String get ocrLanguageJapanese => '日语';

  @override
  String get ocrLanguageKorean => '韩语';

  @override
  String get ocrLanguageDevanagari => '天城文';

  @override
  String get scanDocument => '扫描\n文档';

  @override
  String get camera => '相机';

  @override
  String get gallery => '相册';

  @override
  String get recentScans => '最近扫描';

  @override
  String get allDocuments => '查看文件';

  @override
  String get searchDocuments => '搜索文档';

  @override
  String get sortByDate => '按日期排序';

  @override
  String get sortByName => '按名称排序';

  @override
  String get deleteConfirmTitle => '删除文档？';

  @override
  String get deleteConfirmMessage => '此操作无法撤销。文档将被永久删除。';

  @override
  String get errorOccurred => '发生错误';

  @override
  String get retry => '重试';

  @override
  String get ok => '确定';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get save => '保存';

  @override
  String get close => '关闭';

  @override
  String get extractText => '提取文本';

  @override
  String get extractingText => '正在提取文本...';

  @override
  String get documentName => '文档名称';

  @override
  String get enterDocumentName => '输入文档名称';

  @override
  String get createdAt => '创建于';

  @override
  String get modifiedAt => '修改于';

  @override
  String get size => '大小';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get languageSettings => '语言设置';

  @override
  String get openingScanner => '正在打开扫描仪...';

  @override
  String get savingDocument => '正在保存文档...';

  @override
  String get launchingScanner => '正在启动扫描仪...';

  @override
  String documentExportedTo(String folder) {
    return '已导出到$folder';
  }

  @override
  String get abandonScanTitle => '放弃扫描？';

  @override
  String get abandonScanMessage => '确定要放弃此扫描吗？此操作无法撤销。';

  @override
  String get abandon => '放弃';

  @override
  String get scanSuccessMessage => '完成了！';

  @override
  String get savePromptMessage => '要保存吗？';

  @override
  String get searchFolder => '搜索文件夹...';

  @override
  String get newFolder => '新建';

  @override
  String get folderCreationFailed => '文件夹创建失败';

  @override
  String get myDocs => '我的文档';

  @override
  String get saveHere => '保存到这里';

  @override
  String get export => '导出';

  @override
  String get ocr => 'OCR';

  @override
  String get finish => '完成';

  @override
  String get move => '移动';

  @override
  String get decrypting => '正在解密...';

  @override
  String get loading => '加载中...';

  @override
  String get unableToLoadImage => '无法加载图片';

  @override
  String get noTextDetected => '文档中未检测到文本';

  @override
  String get noTextToShare => '没有可分享的文本';

  @override
  String get shareError => '分享错误';

  @override
  String get folderCreationError => '文件夹创建错误';

  @override
  String get favoriteUpdateFailed => '收藏更新失败';

  @override
  String get documentExported => '文档已导出';

  @override
  String documentsExported(int count) {
    return '已导出$count个文档';
  }

  @override
  String get title => '标题';

  @override
  String get pages => '页';

  @override
  String get format => '格式';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int minutes) {
    return '$minutes分钟前';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours小时前';
  }

  @override
  String daysAgo(int days) {
    return '$days天前';
  }

  @override
  String get lastUpdated => '最后更新';

  @override
  String folderSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择$count个文件夹',
      one: '已选择1个文件夹',
    );
    return '$_temp0';
  }

  @override
  String documentSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择$count个文档',
      one: '已选择1个文档',
    );
    return '$_temp0';
  }

  @override
  String get currentFolder => '当前文件夹';

  @override
  String noResultsFor(String query) {
    return '未找到\"$query\"的结果';
  }

  @override
  String get noFavorites => '无收藏';

  @override
  String get copy => '复制';

  @override
  String get selectAll => '全选';

  @override
  String get selectionModeActive => '选择模式';

  @override
  String get longPressToSelect => '长按选择';

  @override
  String get selectTextEasily => '轻松选择文本';

  @override
  String get selection => '选择';

  @override
  String wordSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择$count个词',
      one: '已选择1个词',
    );
    return '$_temp0';
  }

  @override
  String get renameDocument => '重命名文档';

  @override
  String get newTitle => '新标题...';

  @override
  String get saveUnder => '保存到...';

  @override
  String moveDocuments(int count) {
    return '移动$count个文档';
  }

  @override
  String get chooseDestinationFolder => '选择目标文件夹';

  @override
  String get rootFolder => '根目录（无文件夹）';

  @override
  String get createNewFolder => '创建新文件夹';

  @override
  String get singleDocumentCompressed => '单个压缩文档';

  @override
  String get originalQualityPng => '原始质量 (PNG)';

  @override
  String get pleaseWait => '请稍候...';

  @override
  String get somethingWentWrong => '出错了';

  @override
  String get editFolder => '编辑文件夹';

  @override
  String get folderName => '文件夹名称...';

  @override
  String get create => '创建';

  @override
  String get nameCannotBeEmpty => '名称不能为空';

  @override
  String get createFolderToOrganize => '创建文件夹来整理文档';

  @override
  String get createFolder => '创建文件夹';

  @override
  String get appIsLocked => 'Scanai已锁定';

  @override
  String get authenticateToAccess => '请验证身份以访问文档。';

  @override
  String get unlock => '解锁';

  @override
  String get preparingImage => '正在准备图片...';

  @override
  String get celebrationMessage1 => '简单！';

  @override
  String get celebrationMessage2 => '还来？！';

  @override
  String get celebrationMessage3 => '还需要我吗？';

  @override
  String get celebrationMessage4 => '又完成一个！';

  @override
  String get celebrationMessage5 => '工作完成！';

  @override
  String get celebrationMessage6 => '下一个！';

  @override
  String get shareAppText => '我用Scanai来安全地整理重要文档。快速、安全、流畅！';

  @override
  String get shareAppSubject => 'Scanai：您的安全口袋扫描仪';

  @override
  String get secureYourDocuments => '保护您的文档';

  @override
  String get savedLocally => '全部本地保存';

  @override
  String documentsSecured(int count) {
    return '已保护$count个文档';
  }

  @override
  String get preferences => '偏好设置';

  @override
  String get interface => '界面';

  @override
  String get textRecognition => '文字识别';

  @override
  String get search => '搜索...';

  @override
  String nDocumentsLabel(int count) {
    return '$count个文档';
  }

  @override
  String nFoldersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个文件夹',
      one: '1个文件夹',
    );
    return '$_temp0';
  }

  @override
  String nDocs(int count) {
    return '$count个';
  }

  @override
  String foldersAndDocs(int folders, int documents) {
    String _temp0 = intl.Intl.pluralLogic(
      folders,
      locale: localeName,
      other: '$folders个文件夹',
      one: '1个文件夹',
    );
    String _temp1 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents个文档',
      one: '1个文档',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get scanner => '扫描';

  @override
  String get sortAndFilter => '排序和筛选';

  @override
  String get clearAll => '清除全部';

  @override
  String get sortBy => '排序方式';

  @override
  String get quickFilters => '快速筛选';

  @override
  String get folder => '文件夹';

  @override
  String get tags => '标签';

  @override
  String get apply => '应用';

  @override
  String get favoritesOnly => '仅收藏';

  @override
  String get favoritesOnlyDescription => '仅显示收藏的文档';

  @override
  String get hasOcrText => '有OCR文本';

  @override
  String get hasOcrTextDescription => '仅显示已提取文本的文档';

  @override
  String get failedToLoadFolders => '加载文件夹失败';

  @override
  String get noFoldersYet => '还没有文件夹';

  @override
  String get allDocumentsFilter => '所有文档';

  @override
  String get failedToLoadTags => '加载标签失败';

  @override
  String get noTagsYet => '还没有标签';

  @override
  String get initializingOcr => '正在初始化OCR...';

  @override
  String get ocrSaved => 'OCR文本已保存到文档';

  @override
  String copiedWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已复制$count个词',
      one: '已复制1个词',
    );
    return '$_temp0';
  }

  @override
  String get failedToCopyText => '复制文本失败';

  @override
  String get searchInText => '在文本中搜索...';

  @override
  String matchesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '找到$count个匹配',
      one: '找到1个匹配',
    );
    return '$_temp0';
  }

  @override
  String get done => '完成';

  @override
  String get extractingTextProgress => '正在提取文本...';

  @override
  String processingPage(int current, int total) {
    return '正在处理第$current页，共$total页';
  }

  @override
  String get thisMayTakeAMoment => '请稍等片刻';

  @override
  String get scrollDisabledInSelectionMode => '选择模式 - 滚动已禁用';

  @override
  String get words => '词';

  @override
  String get lines => '行';

  @override
  String get time => '时间';

  @override
  String get noTextFound => '未找到文本';

  @override
  String get noTextFoundDescription => '图片可能不包含可读文本，\n或者质量太低。';

  @override
  String get tryAgain => '重试';

  @override
  String get extractTextTitle => '提取文本';

  @override
  String get extractTextDescription => '运行OCR从此文档中\n提取可读文本。';

  @override
  String get runOcr => '运行OCR';

  @override
  String get allProcessingLocal => '所有处理均在设备本地进行';

  @override
  String get ocrOptions => 'OCR选项';

  @override
  String get documentType => '文档类型';

  @override
  String get auto => '自动';

  @override
  String get singleColumn => '单列';

  @override
  String get singleBlock => '单块';

  @override
  String get sparseText => '稀疏文本';

  @override
  String get rerunOcr => '重新运行OCR';

  @override
  String get saveToDocument => '保存到文档';

  @override
  String get copySelection => '复制选择';

  @override
  String get copySelectionTooltip => '将选中文本复制到剪贴板';

  @override
  String get searchInTextTooltip => '在文本中搜索';

  @override
  String get copyAllTextTooltip => '复制所有文本';

  @override
  String get shareTextTooltip => '分享文本';

  @override
  String get loadingDocuments => '正在加载文档...';

  @override
  String get exportFailed => '导出失败';

  @override
  String get whatAreYouLookingFor => '您在找什么？';

  @override
  String get needHelp => '需要帮助吗？';

  @override
  String get licenses => '开源许可证';

  @override
  String get licensesSubtitle => '查看库许可证';

  @override
  String get localStorageWarningTitle => '仅本地存储';

  @override
  String get localStorageWarningMessage =>
      '您的文档存储在设备上并已加密。如果卸载应用，它们将被永久删除。\n\n请记得导出重要文档！';

  @override
  String get localStorageWarningButton => '知道了';

  @override
  String get deviceSecurityWarningTitle => '安全警告';

  @override
  String get deviceSecurityWarningMessage => '您的设备似乎已获取root权限或越狱。';

  @override
  String get deviceSecurityWarningDetails =>
      '在修改过的设备上，加密、安全存储和生物识别认证等安全功能可能会受到影响。您的文档可能面临风险。\n\n应用将继续运行，但请注意安全性已降低。';

  @override
  String get deviceSecurityContinue => '我明白了';

  @override
  String get showSecurityWarnings => '显示安全警告';

  @override
  String get showSecurityWarningsDescription => '在root或越狱设备上显示警告';

  @override
  String get premiumTitle => '终身高级版';

  @override
  String get premiumSubtitle => '一次购买，解锁所有功能';

  @override
  String get premiumUnlockPotential => '解锁我的全部潜力！';

  @override
  String get premiumNoScansLeft => '免费扫描已用完！';

  @override
  String get premiumOcrRequired => 'OCR仅限高级会员使用';

  @override
  String get premiumExportRequired => 'PDF导出仅限高级会员使用';

  @override
  String get premiumFeatureUnlimitedScans => '无限扫描';

  @override
  String get premiumFeatureMultipage => '多页文档（最多100页）';

  @override
  String get premiumFeaturePdfExport => 'PDF导出';

  @override
  String get premiumFeatureSharing => '文档分享';

  @override
  String get premiumFeatureOcr => '文字提取（OCR）';

  @override
  String premiumPurchaseButton(String price) {
    return '$price解锁';
  }

  @override
  String get premiumRestorePurchases => '恢复购买';

  @override
  String get premiumLater => '以后再说';

  @override
  String get premiumBadgeLabel => '高级版';

  @override
  String get premiumStatusPremium => '高级版';

  @override
  String get premiumStatusPremiumSubtitle => '所有功能已解锁';

  @override
  String get premiumStatusFree => '免费版';

  @override
  String premiumStatusFreeSubtitle(int remaining, int total) {
    return '剩余$remaining/$total次扫描';
  }

  @override
  String get premiumScansRemaining => '剩余扫描次数';

  @override
  String get premiumUpgradeButton => '升级到高级版';

  @override
  String get premiumDebugToggleTitle => '模拟高级版（调试）';

  @override
  String get premiumDebugToggleSubtitle => '启用所有高级功能进行测试';

  @override
  String get premiumDebugResetScans => '重置扫描计数器';

  @override
  String get premiumDebugResetSuccess => '扫描计数器已重置';

  @override
  String get premiumBlockedNoScans => '您已用完所有免费扫描';

  @override
  String get premiumRequiredTitle => '需要高级版';

  @override
  String get premiumRequiredMessage => '此功能需要高级订阅';

  @override
  String get premiumFeatureLockedOcr => 'OCR文字提取是高级功能';

  @override
  String get premiumFeatureLockedExport => 'PDF导出是高级功能';

  @override
  String get premiumFeatureLockedShare => '文档分享是高级功能';

  @override
  String get premiumFeatureLockedMultipage => '多页扫描是高级功能';
}
