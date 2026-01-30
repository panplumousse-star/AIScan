// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Scanai';

  @override
  String get settings => 'Ajustes';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeAuto => 'Automático';

  @override
  String get security => 'Bloqueo';

  @override
  String get enabled => 'Activado';

  @override
  String get disabled => 'Desactivado';

  @override
  String get enableLockTitle => '¿Activar bloqueo?';

  @override
  String get enableLockMessage =>
      '¿Desea proteger el acceso a sus documentos con su huella dactilar?';

  @override
  String get cancel => 'Cancelar';

  @override
  String get enable => 'Activar';

  @override
  String get lockTimeoutImmediate => 'Inmediato';

  @override
  String get lockTimeout1Min => '1 min';

  @override
  String get lockTimeout5Min => '5 min';

  @override
  String get lockTimeout30Min => '30 min';

  @override
  String get about => 'Acerca de';

  @override
  String get developedWith => 'Desarrollado con';

  @override
  String get securityDetails => 'Detalles de seguridad';

  @override
  String get securityTitle => 'Seguridad';

  @override
  String get aes256 => 'AES-256';

  @override
  String get localEncryption => 'Cifrado local';

  @override
  String get zeroKnowledge => 'Zero-Knowledge';

  @override
  String get exclusiveAccess => 'Acceso exclusivo';

  @override
  String get offline => 'Sin conexión';

  @override
  String get securedPercent => '100% seguro';

  @override
  String get settingsSpeechBubbleLine1 => '¿Un pequeño';

  @override
  String get settingsSpeechBubbleLine2 => 'ajuste?';

  @override
  String get dismiss => 'Cerrar';

  @override
  String get myDocuments => 'Mis documentos';

  @override
  String get scan => 'Escanear';

  @override
  String get share => 'Compartir';

  @override
  String get delete => 'Eliminar';

  @override
  String get rename => 'Renombrar';

  @override
  String get noDocuments => 'Sin documentos';

  @override
  String get scanYourFirstDocument => 'Escanea tu primer documento';

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documentos',
      one: '1 documento',
      zero: 'Sin documentos',
    );
    return '$_temp0';
  }

  @override
  String pageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas',
      one: '1 página',
    );
    return '$_temp0';
  }

  @override
  String get greetingMorning => 'Buenos días';

  @override
  String get greetingAfternoon => 'Buenas tardes';

  @override
  String get greetingEvening => 'Buenas noches';

  @override
  String get randomMessage1 => '¿Necesitas un PDF?';

  @override
  String get randomMessage2 => '¿Vamos?';

  @override
  String get randomMessage3 => '¡Esperando tus órdenes!';

  @override
  String get randomMessage4 => '¡Vamos!';

  @override
  String get ocrResults => 'Resultados OCR';

  @override
  String get text => 'Texto';

  @override
  String get metadata => 'Metadatos';

  @override
  String get copyText => 'Copiar';

  @override
  String get textCopied => 'Texto copiado';

  @override
  String get noTextExtracted => 'No se extrajo texto';

  @override
  String get language => 'Idioma';

  @override
  String get processingTime => 'Tiempo de proceso';

  @override
  String get wordCount => 'Número de palabras';

  @override
  String get lineCount => 'Número de líneas';

  @override
  String get confidence => 'Confianza';

  @override
  String get shareAs => 'Compartir como';

  @override
  String get pdf => 'PDF';

  @override
  String get images => 'Imágenes';

  @override
  String get ocrText => 'Texto OCR';

  @override
  String get appLanguage => 'Idioma de la app';

  @override
  String get ocrLanguage => 'Idioma OCR';

  @override
  String get systemLanguage => 'Sistema';

  @override
  String get french => 'Francés';

  @override
  String get english => 'Inglés';

  @override
  String get ocrLanguageAuto => 'Automático';

  @override
  String get ocrLanguageLatin => 'Latino (EN, FR, ES...)';

  @override
  String get ocrLanguageChinese => 'Chino';

  @override
  String get ocrLanguageJapanese => 'Japonés';

  @override
  String get ocrLanguageKorean => 'Coreano';

  @override
  String get ocrLanguageDevanagari => 'Devanagari';

  @override
  String get scanDocument => 'Escanear\ndocumento';

  @override
  String get camera => 'Cámara';

  @override
  String get gallery => 'Galería';

  @override
  String get recentScans => 'Escaneos recientes';

  @override
  String get allDocuments => 'Ver mis archivos';

  @override
  String get searchDocuments => 'Buscar documentos';

  @override
  String get sortByDate => 'Ordenar por fecha';

  @override
  String get sortByName => 'Ordenar por nombre';

  @override
  String get deleteConfirmTitle => '¿Eliminar documento?';

  @override
  String get deleteConfirmMessage =>
      'Esta acción no se puede deshacer. El documento se eliminará permanentemente.';

  @override
  String get errorOccurred => 'Se produjo un error';

  @override
  String get retry => 'Reintentar';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Sí';

  @override
  String get no => 'No';

  @override
  String get save => 'Guardar';

  @override
  String get close => 'Cerrar';

  @override
  String get extractText => 'Extraer texto';

  @override
  String get extractingText => 'Extrayendo texto...';

  @override
  String get documentName => 'Nombre del documento';

  @override
  String get enterDocumentName => 'Ingrese el nombre del documento';

  @override
  String get createdAt => 'Creado';

  @override
  String get modifiedAt => 'Modificado';

  @override
  String get size => 'Tamaño';

  @override
  String get selectLanguage => 'Seleccionar idioma';

  @override
  String get languageSettings => 'Configuración de idioma';

  @override
  String get openingScanner => 'Abriendo escáner...';

  @override
  String get savingDocument => 'Guardando documento...';

  @override
  String get launchingScanner => 'Iniciando escáner...';

  @override
  String documentExportedTo(String folder) {
    return 'Documento exportado a $folder';
  }

  @override
  String get abandonScanTitle => '¿Abandonar escaneo?';

  @override
  String get abandonScanMessage =>
      '¿Está seguro de que desea abandonar este escaneo? Esta acción no se puede deshacer.';

  @override
  String get abandon => 'Abandonar';

  @override
  String get scanSuccessMessage => '¡Listo, está guardado!';

  @override
  String get savePromptMessage => '¿Lo guardamos?';

  @override
  String get searchFolder => 'Buscar carpeta...';

  @override
  String get newFolder => 'Nueva';

  @override
  String get folderCreationFailed => 'Error al crear carpeta';

  @override
  String get myDocs => 'Mis Docs';

  @override
  String get saveHere => 'Guardar aquí';

  @override
  String get export => 'Exportar';

  @override
  String get ocr => 'OCR';

  @override
  String get finish => 'Terminar';

  @override
  String get move => 'Mover';

  @override
  String get decrypting => 'Descifrando...';

  @override
  String get loading => 'Cargando...';

  @override
  String get unableToLoadImage => 'No se puede cargar la imagen';

  @override
  String get noTextDetected => 'No se detectó texto en el documento';

  @override
  String get noTextToShare => 'No hay texto para compartir';

  @override
  String get shareError => 'Error al compartir';

  @override
  String get folderCreationError => 'Error al crear la carpeta';

  @override
  String get favoriteUpdateFailed => 'Error al actualizar favoritos';

  @override
  String get documentExported => 'Documento exportado';

  @override
  String documentsExported(int count) {
    return '$count documentos exportados';
  }

  @override
  String get title => 'Título';

  @override
  String get pages => 'Páginas';

  @override
  String get format => 'Formato';

  @override
  String get justNow => 'Ahora mismo';

  @override
  String minutesAgo(int minutes) {
    return 'Hace $minutes min';
  }

  @override
  String hoursAgo(int hours) {
    return 'Hace ${hours}h';
  }

  @override
  String daysAgo(int days) {
    return 'Hace $days días';
  }

  @override
  String get lastUpdated => 'Última actualización';

  @override
  String folderSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count carpetas seleccionadas',
      one: '1 carpeta seleccionada',
    );
    return '$_temp0';
  }

  @override
  String documentSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documentos seleccionados',
      one: '1 documento seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get currentFolder => 'Carpeta actual';

  @override
  String noResultsFor(String query) {
    return 'Sin resultados para \"$query\"';
  }

  @override
  String get noFavorites => 'Sin favoritos';

  @override
  String get copy => 'Copiar';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get selectionModeActive => 'Modo de selección activo';

  @override
  String get longPressToSelect => 'Mantén presionado para seleccionar';

  @override
  String get selectTextEasily => 'Selecciona texto fácilmente';

  @override
  String get selection => 'Selección';

  @override
  String wordSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras seleccionadas',
      one: '1 palabra seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get renameDocument => 'Renombrar documento';

  @override
  String get newTitle => 'Nuevo título...';

  @override
  String get saveUnder => 'Guardar en...';

  @override
  String moveDocuments(int count) {
    return 'Mover $count documentos';
  }

  @override
  String get chooseDestinationFolder => 'Elige una carpeta de destino';

  @override
  String get rootFolder => 'Raíz (sin carpeta)';

  @override
  String get createNewFolder => 'Crear nueva carpeta';

  @override
  String get singleDocumentCompressed => 'Documento único comprimido';

  @override
  String get originalQualityPng => 'Calidad original (PNG)';

  @override
  String get pleaseWait => 'Por favor espere...';

  @override
  String get somethingWentWrong => '¡Ups! Algo salió mal';

  @override
  String get editFolder => 'Editar carpeta';

  @override
  String get folderName => 'Nombre de carpeta...';

  @override
  String get create => 'Crear';

  @override
  String get nameCannotBeEmpty => 'El nombre no puede estar vacío';

  @override
  String get createFolderToOrganize =>
      'Crea una carpeta para organizar tus documentos';

  @override
  String get createFolder => 'Crear carpeta';

  @override
  String get appIsLocked => 'Scanai está bloqueado';

  @override
  String get authenticateToAccess =>
      'Autentícate para acceder a tus documentos seguros.';

  @override
  String get unlock => 'Desbloquear';

  @override
  String get preparingImage => 'Preparando imagen...';

  @override
  String get celebrationMessage1 => '¡Fácil!';

  @override
  String get celebrationMessage2 => '¿Otra vez?!';

  @override
  String get celebrationMessage3 => '¿Me necesitas de nuevo?';

  @override
  String get celebrationMessage4 => '¡Uno más listo!';

  @override
  String get celebrationMessage5 => '¡Trabajo hecho!';

  @override
  String get celebrationMessage6 => '¡Siguiente!';

  @override
  String get shareAppText =>
      'Uso Scanai para proteger y organizar mis documentos importantes. ¡Es rápido, seguro y fluido!';

  @override
  String get shareAppSubject => 'Scanai: Tu escáner de bolsillo seguro';

  @override
  String get secureYourDocuments => 'Protege tus documentos';

  @override
  String get savedLocally => 'Todo guardado localmente';

  @override
  String documentsSecured(int count) {
    return '$count documentos protegidos';
  }

  @override
  String get preferences => 'Preferencias';

  @override
  String get interface => 'Interfaz';

  @override
  String get textRecognition => 'Reconocimiento de texto';

  @override
  String get search => 'Buscar...';

  @override
  String nDocumentsLabel(int count) {
    return '$count documentos';
  }

  @override
  String nFoldersLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count carpetas',
      one: '1 carpeta',
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
      other: '$folders carpetas',
      one: '1 carpeta',
    );
    String _temp1 = intl.Intl.pluralLogic(
      documents,
      locale: localeName,
      other: '$documents documentos',
      one: '1 documento',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get scanner => 'Escanear';

  @override
  String get sortAndFilter => 'Ordenar y Filtrar';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get quickFilters => 'Filtros rápidos';

  @override
  String get folder => 'Carpeta';

  @override
  String get tags => 'Etiquetas';

  @override
  String get apply => 'Aplicar';

  @override
  String get favoritesOnly => 'Solo favoritos';

  @override
  String get favoritesOnlyDescription =>
      'Mostrar solo documentos marcados como favoritos';

  @override
  String get hasOcrText => 'Tiene texto OCR';

  @override
  String get hasOcrTextDescription =>
      'Mostrar solo documentos con texto extraído';

  @override
  String get failedToLoadFolders => 'Error al cargar carpetas';

  @override
  String get noFoldersYet => 'Aún no hay carpetas creadas';

  @override
  String get allDocumentsFilter => 'Todos los documentos';

  @override
  String get failedToLoadTags => 'Error al cargar etiquetas';

  @override
  String get noTagsYet => 'Aún no hay etiquetas creadas';

  @override
  String get initializingOcr => 'Inicializando OCR...';

  @override
  String get ocrSaved => 'Texto OCR guardado en el documento';

  @override
  String copiedWords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count palabras copiadas',
      one: '1 palabra copiada',
    );
    return '$_temp0 al portapapeles';
  }

  @override
  String get failedToCopyText => 'Error al copiar texto al portapapeles';

  @override
  String get searchInText => 'Buscar en el texto...';

  @override
  String matchesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coincidencias encontradas',
      one: '1 coincidencia encontrada',
    );
    return '$_temp0';
  }

  @override
  String get done => 'Listo';

  @override
  String get extractingTextProgress => 'Extrayendo texto...';

  @override
  String processingPage(int current, int total) {
    return 'Procesando página $current de $total';
  }

  @override
  String get thisMayTakeAMoment => 'Esto puede tardar un momento';

  @override
  String get scrollDisabledInSelectionMode =>
      'Modo de selección activo - desplazamiento deshabilitado';

  @override
  String get words => 'Palabras';

  @override
  String get lines => 'Líneas';

  @override
  String get time => 'Tiempo';

  @override
  String get noTextFound => 'No se encontró texto';

  @override
  String get noTextFoundDescription =>
      'La imagen puede no contener texto legible,\no la calidad puede ser demasiado baja.';

  @override
  String get tryAgain => 'Intentar de nuevo';

  @override
  String get extractTextTitle => 'Extraer texto';

  @override
  String get extractTextDescription =>
      'Ejecutar OCR para extraer texto legible\nde este documento.';

  @override
  String get runOcr => 'Ejecutar OCR';

  @override
  String get allProcessingLocal =>
      'Todo el procesamiento ocurre localmente en tu dispositivo';

  @override
  String get ocrOptions => 'Opciones de OCR';

  @override
  String get documentType => 'Tipo de documento';

  @override
  String get auto => 'Automático';

  @override
  String get singleColumn => 'Columna única';

  @override
  String get singleBlock => 'Bloque único';

  @override
  String get sparseText => 'Texto disperso';

  @override
  String get rerunOcr => 'Re-ejecutar OCR';

  @override
  String get saveToDocument => 'Guardar en documento';

  @override
  String get copySelection => 'Copiar selección';

  @override
  String get copySelectionTooltip =>
      'Copiar texto seleccionado al portapapeles';

  @override
  String get searchInTextTooltip => 'Buscar en el texto';

  @override
  String get copyAllTextTooltip => 'Copiar todo el texto';

  @override
  String get shareTextTooltip => 'Compartir texto';

  @override
  String get loadingDocuments => 'Cargando tus documentos...';

  @override
  String get exportFailed => 'Error en la exportación';

  @override
  String get whatAreYouLookingFor => '¿Qué estás buscando?';

  @override
  String get needHelp => '¿Necesitas ayuda?';

  @override
  String get licenses => 'Licencias de código abierto';

  @override
  String get licensesSubtitle => 'Ver licencias de bibliotecas';

  @override
  String get localStorageWarningTitle => 'Solo almacenamiento local';

  @override
  String get localStorageWarningMessage =>
      'Tus documentos se almacenan en tu dispositivo y están cifrados. Si desinstalas la app, se eliminarán permanentemente.\n\n¡Recuerda exportar tus documentos importantes!';

  @override
  String get localStorageWarningButton => 'Entendido';

  @override
  String get deviceSecurityWarningTitle => 'Advertencia de seguridad';

  @override
  String get deviceSecurityWarningMessage =>
      'Tu dispositivo parece estar rooteado o con jailbreak.';

  @override
  String get deviceSecurityWarningDetails =>
      'En dispositivos modificados, las funciones de seguridad como el cifrado, el almacenamiento seguro y la autenticación biométrica pueden estar comprometidas. Tus documentos pueden estar en riesgo.\n\nLa app seguirá funcionando, pero ten en cuenta la seguridad reducida.';

  @override
  String get deviceSecurityContinue => 'Entiendo';

  @override
  String get showSecurityWarnings => 'Mostrar advertencias de seguridad';

  @override
  String get showSecurityWarningsDescription =>
      'Mostrar advertencias al ejecutar en dispositivos rooteados o con jailbreak';

  @override
  String get premiumTitle => 'Premium de por vida';

  @override
  String get premiumSubtitle =>
      'Desbloquea todas las funciones con una compra única';

  @override
  String get premiumUnlockPotential => '¡Desbloquea todo mi potencial!';

  @override
  String get premiumNoScansLeft => '¡Te has quedado sin escaneos gratuitos!';

  @override
  String get premiumOcrRequired => 'OCR está reservado para miembros premium';

  @override
  String get premiumExportRequired =>
      'La exportación PDF está reservada para miembros premium';

  @override
  String get premiumFeatureUnlimitedScans => 'Escaneos ilimitados';

  @override
  String get premiumFeatureMultipage =>
      'Documentos de varias páginas (hasta 100)';

  @override
  String get premiumFeaturePdfExport => 'Exportación PDF';

  @override
  String get premiumFeatureSharing => 'Compartir documentos';

  @override
  String get premiumFeatureOcr => 'Extracción de texto (OCR)';

  @override
  String premiumPurchaseButton(String price) {
    return 'Desbloquear por $price';
  }

  @override
  String get premiumRestorePurchases => 'Restaurar compras';

  @override
  String get premiumLater => 'Quizás más tarde';

  @override
  String get premiumBadgeLabel => 'Premium';

  @override
  String get premiumStatusPremium => 'Premium';

  @override
  String get premiumStatusPremiumSubtitle =>
      'Todas las funciones desbloqueadas';

  @override
  String get premiumStatusFree => 'Gratis';

  @override
  String premiumStatusFreeSubtitle(int remaining, int total) {
    return '$remaining de $total escaneos restantes';
  }

  @override
  String get premiumScansRemaining => 'Escaneos restantes';

  @override
  String get premiumUpgradeButton => 'Actualizar a Premium';

  @override
  String get premiumDebugToggleTitle => 'Simular Premium (Debug)';

  @override
  String get premiumDebugToggleSubtitle =>
      'Activar todas las funciones premium para pruebas';

  @override
  String get premiumDebugResetScans => 'Reiniciar contador de escaneos';

  @override
  String get premiumDebugResetSuccess => 'Contador de escaneos reiniciado';

  @override
  String get premiumBlockedNoScans => 'Has usado todos tus escaneos gratuitos';

  @override
  String get premiumRequiredTitle => 'Se requiere Premium';

  @override
  String get premiumRequiredMessage =>
      'Esta función requiere una suscripción Premium';

  @override
  String get premiumFeatureLockedOcr =>
      'La extracción de texto OCR es una función Premium';

  @override
  String get premiumFeatureLockedExport =>
      'La exportación PDF es una función Premium';

  @override
  String get premiumFeatureLockedShare =>
      'Compartir documentos es una función Premium';

  @override
  String get premiumFeatureLockedMultipage =>
      'El escaneo de varias páginas es una función Premium';
}
