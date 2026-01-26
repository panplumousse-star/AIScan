import 'dart:async';
import 'dart:math';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/accessibility_config.dart';
import '../../../core/permissions/camera_permission_service.dart';
import '../../../core/permissions/permission_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_lock/domain/app_lock_service.dart';
import '../../../core/storage/document_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/bento_interactive_wrapper.dart';
import '../../../core/widgets/bouncing_widget.dart';
import '../../../core/widgets/scanai_loader.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/widgets/bento_mascot.dart';
import '../../../core/widgets/bento_speech_bubble.dart';
import 'package:share_plus/share_plus.dart';

/// Provider that gets the total document count.
final totalDocumentCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.read(documentRepositoryProvider);
  final documents = await repository.getAllDocuments();
  return documents.length;
});

/// Provider for a random greeting subtitle index.
final greetingSubtitleIndexProvider = Provider.autoDispose<int>((ref) {
  return Random().nextInt(4);
});

/// Provider to track if a scan has just been completed.
final hasJustScannedProvider = StateProvider<bool>((ref) => false);

/// Provider for celebratory messages index after a scan.
final celebrationMessageIndexProvider = Provider.autoDispose<int>((ref) {
  return Random().nextInt(6);
});

/// Provider for the number of documents secured in the current month.
final monthlyScanCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(documentRepositoryProvider);
  final documents = await repository.getAllDocuments();
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month);
  
  return documents.where((d) => d.createdAt.isAfter(startOfMonth)).length;
});

class BentoHomeScreen extends ConsumerStatefulWidget {
  const BentoHomeScreen({super.key});

  @override
  ConsumerState<BentoHomeScreen> createState() => _BentoHomeScreenState();
}

class _BentoHomeScreenState extends ConsumerState<BentoHomeScreen> with WidgetsBindingObserver {
  Timer? _idleTimer;
  Timer? _sleepTimer;
  Timer? _unlockTimer;
  bool _isSleeping = false;
  bool _showUnlockMascot = false;
  int _sleepMessageIndex = 0;
  int _mascotKey = 0; // Key to force mascot rebuild for animation

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetIdleTimer();
  }

  void _handleUnlockStateChange(bool? previous, bool justUnlocked) {
    if (justUnlocked) {
      // Reset the provider immediately
      ref.read(justUnlockedProvider.notifier).state = false;

      // Show unlock mascot for 5 seconds
      setState(() {
        _showUnlockMascot = true;
        _isSleeping = false;
      });

      _unlockTimer?.cancel();
      _unlockTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showUnlockMascot = false;
            _mascotKey++; // Force rebuild for waving animation
          });
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _sleepTimer?.cancel();
    _unlockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // App revient au premier plan - réveiller la mascotte et relancer l'animation
      setState(() {
        _isSleeping = false;
        _sleepTimer?.cancel();
        _sleepMessageIndex = 0;
        _mascotKey++; // Force rebuild pour relancer l'animation hello
      });
      _resetIdleTimer();
    } else if (state == AppLifecycleState.paused) {
      // App passe en arrière-plan - annuler les timers
      _idleTimer?.cancel();
      _sleepTimer?.cancel();
    }
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) {
        setState(() {
          _isSleeping = true;
          _startSleepTimer();
        });
      }
    });
  }

  void _startSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _sleepMessageIndex = (_sleepMessageIndex + 1) % 5;
        });
      }
    });
  }

  void _handleInteraction() {
    if (_isSleeping) {
      setState(() {
        _isSleeping = false;
        _sleepTimer?.cancel();
        _sleepMessageIndex = 0;
      });
    }
    _resetIdleTimer();
  }

  Future<bool> _checkAndRequestPermission(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final permissionService = ref.read(cameraPermissionServiceProvider);
    final state = await permissionService.checkPermission();

    if (state == CameraPermissionState.granted ||
        state == CameraPermissionState.sessionOnly) {
      return true;
    }

    if (await permissionService.isFirstTimeRequest()) {
      final result = await permissionService.requestSystemPermission();
      if (result == CameraPermissionState.granted ||
          result == CameraPermissionState.sessionOnly) {
        return true;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('Camera permission is required to scan documents'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => permissionService.openSettings(),
            ),
          ),
        );
      }
      return false;
    }

    if (await permissionService.isPermissionBlocked()) {
      if (!context.mounted) return false;
      final shouldOpenSettings = await showCameraSettingsDialog(context);
      if (shouldOpenSettings == true) {
        await permissionService.openSettings();
      }
      return false;
    }
    return false;
  }

  void _navigateToScanner(
    BuildContext context,
    WidgetRef ref,
  ) async {
    unawaited(HapticFeedback.lightImpact());
    unawaited(ref.read(audioServiceProvider).playScanLaunch());
    final hasPermission = await _checkAndRequestPermission(context, ref);
    if (hasPermission && context.mounted) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          opaque: true,
          barrierColor: isDark ? Colors.black : Colors.white,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ScannerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ColoredBox(
              color: isDark ? Colors.black : Colors.white,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        ),
      ).then((_) {
        // Refresh document counts when returning from scanner
        // This ensures the home screen reflects any newly scanned documents
        if (mounted) {
          ref.invalidate(totalDocumentCountProvider);
          ref.invalidate(monthlyScanCountProvider);
        }
      });
    }
  }

  void _handleAppShare(BuildContext context) {
    unawaited(HapticFeedback.mediumImpact());
    final l10n = AppLocalizations.of(context);
    const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.plumstudio.scanai';
    final shareText = '${l10n?.shareAppText ?? 'I use Scanai to secure and organize my important documents.'}\n\n$playStoreUrl';
    unawaited(Share.share(
      shareText,
      subject: l10n?.shareAppSubject ?? 'Scanai: Your secure pocket scanner',
    ));
  }

  String _getGreeting(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n?.greetingMorning ?? 'Bonjour';
    if (hour < 18) return l10n?.greetingAfternoon ?? 'Bon apres-midi';
    return l10n?.greetingEvening ?? 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    // Listen for unlock state changes (when lock screen pops)
    ref.listen<bool>(justUnlockedProvider, _handleUnlockStateChange);

    return Listener(
      onPointerDown: (_) => _handleInteraction(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
      backgroundColor: Colors.transparent, // Let BentoBackground show through
      body: Stack(
        children: [
          // 1. Background Refinements: Blobs & Texture
          const BentoBackground(),

          SafeArea(
            child: Column(
              children: [
                // Gap instead of top bar
                const SizedBox(height: 8),

                // Shift content down slightly
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                // Scrollable Content
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Colors.white, Colors.transparent],
                        stops: const [0.0, 0.9, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16), // Increased spacing
                          
                          // 1. Top Row: Greeting (Small/Medium) + Mascot (Medium/Large)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Greeting Tile (40%)
                              Expanded(
                                flex: 5,
                                child: BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 0),
                                  child: _buildGreetingCard(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Mascot Tile (60%)
                              Expanded(
                                flex: 5,
                                child: BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 50),
                                  child: _buildMascotCard(),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 32), // Increased spacing

                          // 2. Scan Tile (Prominent CTA)
                          BentoAnimatedEntry(
                            delay: const Duration(milliseconds: 100),
                            child: _buildScanCard(context),
                          ),

                          const SizedBox(height: 32), // Increased spacing

                          // 3. Bottom Row: Documents (Large) + Info/Version (Small)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Documents Tile (65%)
                              Expanded(
                                flex: 65,
                                child: BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 200),
                                  child: ref.watch(totalDocumentCountProvider).when(
                                    data: (count) => _buildDocumentsCard(context, count),
                                    loading: () => _buildDocumentsCard(context, 0, isLoading: true),
                                    error: (_, __) => _buildDocumentsCard(context, 0),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Settings Tile (35%)
                              Expanded(
                                flex: 35,
                                child: BentoAnimatedEntry(
                                  delay: const Duration(milliseconds: 300),
                                  child: _buildSettingsCard(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40), // Bottom breathing room
                        ],
                      ),
                    ),
                  ),
                ),

                // Footer Content: Interactive Bento Stat & Share
                _buildInteractiveFooter(context),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInteractiveFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthlyScans = ref.watch(monthlyScanCountProvider).value ?? 0;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Semantics(
        label: 'Share Scanai app',
        hint: 'Share this app with others',
        button: true,
        enabled: true,
        child: BentoInteractiveWrapper(
          onTap: () => _handleAppShare(context),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : AppColors.bentoCardWhite,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark 
                  ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) 
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthlyScans > 0
                          ? (l10n?.documentsSecured(monthlyScans) ?? '$monthlyScans documents secured')
                          : (l10n?.secureYourDocuments ?? 'Secure your documents'),
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.surfaceVariantLight : const Color(0xFF1E1B4B),
                      ),
                    ),
                    Text(
                      l10n?.savedLocally ?? 'Everything saved locally',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        color: isDark ? AppColors.neutralDark : AppColors.neutralLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              BouncingWidget(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark 
                          ? const Color(0xFF818CF8).withValues(alpha: 0.2)
                          : const Color(0xFF6366F1).withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/scanai_kdo.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    final hasJustScanned = ref.watch(hasJustScannedProvider);
    final greetingSubtitleIndex = ref.watch(greetingSubtitleIndexProvider);
    final celebrationMessageIndex = ref.watch(celebrationMessageIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    // Localized greeting subtitles
    final greetingSubtitles = [
      l10n?.randomMessage1 ?? "Besoin d'un PDF ?",
      l10n?.randomMessage2 ?? "Let's Go ?",
      l10n?.randomMessage3 ?? "J'attends tes ordres !",
      l10n?.randomMessage4 ?? "Allons-y !",
    ];
    final greetingSubtitle = greetingSubtitles[greetingSubtitleIndex];

    // Localized celebration messages
    final celebrationMessages = [
      l10n?.celebrationMessage1 ?? "Easy !",
      l10n?.celebrationMessage2 ?? "On r'commence ?!",
      l10n?.celebrationMessage3 ?? "Encore besoin de moi ?",
      l10n?.celebrationMessage4 ?? "Et hop, un de plus !",
      l10n?.celebrationMessage5 ?? "Travail termine !",
      l10n?.celebrationMessage6 ?? "Au suivant!",
    ];
    final celebrationMessage = celebrationMessages[celebrationMessageIndex];

    // Build semantic label for screen readers
    final String greetingText = _isSleeping
        ? [
            "Zzz",
            "Zzz .",
            "Zzz ..",
            "Zzz ...",
            "Zzz ... Zzz"
          ][_sleepMessageIndex]
        : (hasJustScanned ? celebrationMessage : _getGreeting(context));

    final String semanticLabel = (!hasJustScanned && !_isSleeping)
        ? '$greetingText. $greetingSubtitle'
        : greetingText;

    return BentoAnimatedEntry(
      delay: const Duration(milliseconds: 0),
      child: BentoInteractiveWrapper(
        onTap: () {
          HapticFeedback.lightImpact();
          if (hasJustScanned) {
            ref.read(hasJustScannedProvider.notifier).state = false;
          }
        },
        child: Semantics(
          label: semanticLabel,
          excludeSemantics: true,
          child: SizedBox(
            height: 140, // Match mascot card height
            child: Align(
              alignment: Alignment.bottomCenter, // Align bubble to the bottom
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _isSleeping ? (0.8 + (_sleepMessageIndex % 2 == 0 ? 0.2 : 0.0)) : 1.0,
                child: SizedBox(
                  height: 85,
                  child: BentoSpeechBubble(
                    tailDirection: BubbleTailDirection.right,
                    color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.6) : AppColors.surfaceLight,
                    borderColor: isDark
                        ? AppColors.surfaceLight.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 32, // Fixed height to prevent vertical jumps
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _isSleeping
                                    ? [
                                        "Zzz",
                                        "Zzz .",
                                        "Zzz ..",
                                        "Zzz ...",
                                        "Zzz ... Zzz"
                                      ][_sleepMessageIndex]
                                    : (hasJustScanned ? celebrationMessage : _getGreeting(context)),
                                style: TextStyle(
                          fontFamily: 'Outfit',
                                  fontSize: (hasJustScanned || _isSleeping) ? 22 : 24,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.surfaceVariantLight : AppColors.surfaceVariantDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!hasJustScanned && !_isSleeping) ...[
                          const SizedBox(height: 2),
                          Text(
                            greetingSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                          fontFamily: 'Outfit',
                              fontSize: 12,
                              color: isDark ? AppColors.neutralDark : AppColors.neutralLight,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMascotCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BentoInteractiveWrapper(
      onTap: () {
        HapticFeedback.mediumImpact();
        // Potential secret animation trigger here later?
      },
      child: ExcludeSemantics(
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.6) : AppColors.surfaceVariantLight,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: isDark
                  ? AppColors.surfaceLight.withValues(alpha: 0.1)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.surfaceDark.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (_isSleeping)
                BouncingWidget(
                  child: Image.asset(
                    'assets/images/scanai_zzz.png',
                    height: 180, // Enlarged
                    fit: BoxFit.contain,
                  ),
                )
              else if (_showUnlockMascot)
                BouncingWidget(
                  child: BentoMascot(
                    key: const ValueKey('unlock_mascot'),
                    height: 180,
                    variant: BentoMascotVariant.unlock,
                  ),
                )
              else
                BentoMascot(
                  key: ValueKey('home_mascot_$_mascotKey'),
                  height: 180,
                  // animateOnce: false → loops 6 cycles, pauses 10s, repeats
                  // Stops only on sleep mode or page navigation
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return _ShakeableWrapper(
      onTap: () => _navigateToScanner(context, ref),
      semanticLabel: A11yLabels.scanDocument,
      semanticHint: A11yLabels.scanDocumentHint,
      child: Container(
        width: double.infinity,
        height: 180, // Reduced height for better fit
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: AppGradients.scanner,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.15),
            width: 1.5,
          ),
          boxShadow: [
            // Soft multi-layered shadow
            BoxShadow(
              color: (isDark ? Colors.black : AppColors.primaryLight).withValues(alpha: isDark ? 0.3 : 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              // Static, smaller icon on the left
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset(
                  'assets/images/scanner_icone.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 32), // Increased for symmetry
              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n?.scanDocument ?? 'Scanner un\ndocument',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16), // Increased spacing
                    _PulsingGlow(
                      glowColor: Colors.white,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              l10n?.scan ?? 'Scanner',
                              style: TextStyle(
                        fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsCard(BuildContext context, int count, {bool isLoading = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmpty = count == 0 && !isLoading;
    final l10n = AppLocalizations.of(context);

    // Generate semantic label based on state
    String semanticLabel;
    String? semanticHint;

    if (isLoading) {
      semanticLabel = A11yLabels.loadingDocuments;
      semanticHint = null;
    } else if (isEmpty) {
      semanticLabel = 'Documents, no documents available';
      semanticHint = 'Scan a document to get started';
    } else {
      semanticLabel = A11yLabels.folderWithCount('Documents', count);
      semanticHint = 'Opens your documents library';
    }

    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      enabled: !isEmpty,
      child: Opacity(
        opacity: isEmpty ? 0.5 : 1.0,
        child: BentoInteractiveWrapper(
          onTap: isEmpty
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  ref.read(audioServiceProvider).playSwoosh();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                  );
                },
          child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : AppColors.bentoCardWhite,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark 
                ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) 
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.1 : 0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.folder_copy_rounded,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.myDocuments ?? 'Documents',
                        style: TextStyle(
                        fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.surfaceVariantLight : const Color(0xFF1E1B4B),
                        ),
                      ),
                      Text(
                        count > 0 ? (l10n?.allDocuments ?? 'Voir mes fichiers') : (l10n?.noDocuments ?? 'Aucun document'),
                        style: TextStyle(
                        fontFamily: 'Outfit',
                          fontSize: 14,
                          color: isDark
                              ? AppColors.neutralDark
                              : const Color(0xFF6366F1).withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Bottom Right Arrow
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFEEF2FF).withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                  size: 16,
                ),
              ),
            ),

            if (isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black45 : AppColors.bentoOrangePastel.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const ScanaiLoader(size: 32),
                ),
              ),

            if (count > 0 && !isLoading)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                        fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: A11yLabels.settings,
      hint: 'Open app settings',
      button: true,
      enabled: true,
      child: BentoInteractiveWrapper(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
        child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.6) : AppColors.bentoBackground,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFEEF2FF), // Soft Indigo background
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1), // Vibrant Indigo
                size: 20,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.settings ?? 'Reglages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                        fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.surfaceVariantLight : const Color(0xFF1E1B4B), // Deep Indigo / Off White
                  ),
                ),
                Text(
                  l10n?.appearance ?? 'Preferences',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                        fontFamily: 'Outfit',
                    fontSize: 11,
                    color: isDark
                        ? AppColors.neutralDark
                        : const Color(0xFF6366F1).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}


class _FloatingAsset extends StatefulWidget {
  final double height;
  final String assetPath;
  final Offset offset;

  const _FloatingAsset({
    required this.height,
    required this.assetPath,
    required this.offset,
  });

  @override
  State<_FloatingAsset> createState() => _FloatingAssetState();
}

class _FloatingAssetState extends State<_FloatingAsset>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 10),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: widget.offset.dx,
      bottom: widget.offset.dy,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.translate(
            offset: _animation.value,
            child: child,
          );
        },
        child: Image.asset(
          widget.assetPath,
          height: widget.height,
          fit: BoxFit.contain,
          alignment: Alignment.bottomRight,
        ),
      ),
    );
  }
}


class _PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;

  const _PulsingGlow({
    required this.child,
    required this.glowColor,
  });

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(begin: 2.0, end: 12.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.3 * (_controller.value + 0.5)),
                blurRadius: _glowAnimation.value,
                spreadRadius: _glowAnimation.value / 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _ShakeableWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;
  final String? semanticHint;

  const _ShakeableWrapper({
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.semanticHint,
  });

  @override
  State<_ShakeableWrapper> createState() => _ShakeableWrapperState();
}

class _ShakeableWrapperState extends State<_ShakeableWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 70),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -4.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    HapticFeedback.vibrate(); // Stronger feedback for launch
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      button: true,
      enabled: true,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value, 0),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _RotatingWidget extends StatefulWidget {
  final Widget child;
  const _RotatingWidget({required this.child});

  @override
  State<_RotatingWidget> createState() => _RotatingWidgetState();
}

class _RotatingWidgetState extends State<_RotatingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(seconds: 20), // Slower, more majestic rotation
        vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: widget.child,
    );
  }
}

