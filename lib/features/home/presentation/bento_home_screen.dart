import 'dart:async';
import 'dart:math';
import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/permissions/camera_permission_service.dart';
import '../../../core/permissions/permission_dialog.dart';
import '../../../core/storage/document_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_card.dart';
import '../../../core/widgets/bento_background.dart';
import '../../../core/widgets/scanai_loader.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../core/services/audio_service.dart';
import 'package:share_plus/share_plus.dart';

/// Provider that gets recent document names for preview (optional usage).
final recentDocumentsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final repository = ref.read(documentRepositoryProvider);
  final documents = await repository.getAllDocuments();
  final sorted = documents.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(3).map((d) => d.title).toList();
});

/// Provider for a random greeting subtitle to avoid monotony.
final greetingSubtitleProvider = Provider.autoDispose<String>((ref) {
  final messages = [
    "Besoin d'un PDF ?",
    "Let's Go ?",
    "J'attends tes ordres !",
    "Allons-y !",
  ];
  return messages[Random().nextInt(messages.length)];
});

/// Provider to track if a scan has just been completed.
final hasJustScannedProvider = StateProvider<bool>((ref) => false);

/// Provider for celebratory messages after a scan.
final celebrationMessageProvider = Provider.autoDispose<String>((ref) {
  final messages = [
    "Easy !",
    "On r'commence ?!",
    "Encore besoin de moi ?",
    "Et hop, un de plus !",
    "Travail terminé !",
    "Au suivant!",
  ];
  return messages[Random().nextInt(messages.length)];
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

class _BentoHomeScreenState extends ConsumerState<BentoHomeScreen> {
  Timer? _idleTimer;
  Timer? _sleepTimer;
  bool _isSleeping = false;
  int _sleepMessageIndex = 0;

  @override
  void initState() {
    super.initState();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _sleepTimer?.cancel();
    super.dispose();
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
    HapticFeedback.lightImpact();
    ref.read(audioServiceProvider).playScanLaunch();
    final hasPermission = await _checkAndRequestPermission(context, ref);
    if (hasPermission && context.mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ScannerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  void _handleAppShare(BuildContext context) {
    HapticFeedback.mediumImpact();
    Share.share(
      'J\'utilise Scanai pour sécuriser et classer mes documents importants. C\'est rapide, sécurisé et ultra-fluide ! 🚀📂 #Scanai',
      subject: 'Scanai : Ton scanner de poche sécurisé',
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 18) return 'Bonjour !';
    return 'Bonsoir !';
  }

  @override
  Widget build(BuildContext context) {
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
                                  child: ref.watch(recentDocumentsProvider).when(
                                    data: (docs) => _buildDocumentsCard(context, docs.length),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: _BentoInteractiveWrapper(
        onTap: () => _handleAppShare(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
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
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
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
                          ? '$monthlyScans documents sécurisés'
                          : 'Sécurisez vos documents',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
                      ),
                    ),
                    Text(
                      'Tout est sauvegardé localement',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _BouncingWidget(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F3FF),
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
    );
  }

  Widget _buildGreetingCard() {
    final hasJustScanned = ref.watch(hasJustScannedProvider);
    final greetingSubtitle = ref.watch(greetingSubtitleProvider);
    final celebrationMessage = ref.watch(celebrationMessageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BentoAnimatedEntry(
      delay: const Duration(milliseconds: 0),
      child: _BentoInteractiveWrapper(
        onTap: () {
          HapticFeedback.lightImpact();
          if (hasJustScanned) {
            ref.read(hasJustScannedProvider.notifier).state = false;
          }
        },
        child: SizedBox(
          height: 140, // Match mascot card height
          child: Align(
            alignment: Alignment.bottomCenter, // Align bubble to the bottom
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _isSleeping ? (0.8 + (_sleepMessageIndex % 2 == 0 ? 0.2 : 0.0)) : 1.0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The Bubble Body
                  Container(
                    height: 85,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
                      borderRadius: BorderRadius.circular(16), // Reduced rounding
                      border: Border.all(
                        color: isDark 
                            ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) 
                            : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                      : (hasJustScanned ? celebrationMessage : _getGreeting()),
                                  style: GoogleFonts.outfit(
                                    fontSize: (hasJustScanned || _isSleeping) ? 22 : 24,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
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
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // The Bubble Tail (Pointing Right to Scanai)
                  Positioned(
                    right: -10, 
                    top: 12,    // Moved to top-right
                    child: CustomPaint(
                      size: const Size(12, 16),
                      painter: _BubbleTailPainter(
                        color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
                        borderColor: isDark 
                            ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) 
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMascotCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _BentoInteractiveWrapper(
      onTap: () {
        HapticFeedback.mediumImpact();
        // Potential secret animation trigger here later?
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : const Color(0xFFF1F5F9), // Light grey or obsidian
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
              _BouncingWidget(
                child: Image.asset(
                  'assets/images/scanai_zzz.png',
                  height: 180, // Enlarged
                  fit: BoxFit.contain,
                ),
              )
            else
              const _WavingMascot(
                height: 180, // Enlarged
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ShakeableWrapper(
      onTap: () => _navigateToScanner(context, ref),
      child: Container(
        width: double.infinity,
        height: 180, // Reduced height for better fit
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [
                    const Color(0xFF312E81), // Extra Deep Indigo
                    const Color(0xFF3730A3), // Deep Indigo
                    const Color(0xFF1E1B4B), // Midnight Indigo
                  ]
                : [
                    const Color(0xFF6366F1), // Indigo
                    const Color(0xFF4F46E5), // Primary
                    const Color(0xFF3730A3), // Deep Indigo
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.15),
            width: 1.5,
          ),
          boxShadow: [
            // Soft multi-layered shadow
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF4F46E5)).withValues(alpha: isDark ? 0.3 : 0.2),
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
                      'Scanner un\ndocument',
                      style: GoogleFonts.outfit(
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
                                  color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              'Tap pour démarrer',
                              style: GoogleFonts.outfit(
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
    return _BentoInteractiveWrapper(
      onTap: () {
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
          color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : Colors.white,
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
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
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
                        'Documents',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
                        ),
                      ),
                      Text(
                        count > 0 ? '$count documents' : 'Ma bibliothèque',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: isDark 
                              ? const Color(0xFF94A3B8) 
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
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF).withValues(alpha: 0.5),
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
                    color: isDark ? Colors.black45 : const Color(0xFFFFF7ED).withValues(alpha: 0.5),
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
                    '+$count',
                    style: GoogleFonts.outfit(
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
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _BentoInteractiveWrapper(
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
          color: isDark ? const Color(0xFF000000).withValues(alpha: 0.6) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark 
                ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) 
                : const Color(0xFFFFFFFF).withValues(alpha: 0.6),
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
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF), // Soft Indigo background
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
                  'Réglages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B), // Deep Indigo / Off White
                  ),
                ),
                Text(
                  'Préférences',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark 
                        ? const Color(0xFF94A3B8) 
                        : const Color(0xFF6366F1).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WavingMascot extends ConsumerStatefulWidget {
  final double height;

  const _WavingMascot({
    required this.height,
  });

  @override
  ConsumerState<_WavingMascot> createState() => _WavingMascotState();
}

class _WavingMascotState extends ConsumerState<_WavingMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isStarted = false;
  bool _isAnimationFinished = false;

  @override
  void initState() {
    super.initState();
    // 480ms for one full cycle
    _controller = AnimationController(
      duration: const Duration(milliseconds: 480),
      vsync: this,
    );

    // Immediate start
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isStarted = true;
          _controller.repeat();
        });
      }
    });

    // Stop waving after exactly 6 cycles
    Future.delayed(const Duration(milliseconds: 2930), () {
      if (mounted) {
        // Trigger sound and haptic feedback
        ref.read(audioServiceProvider).playPock();
        HapticFeedback.lightImpact();
        
        setState(() {
          _isAnimationFinished = true;
          _controller.stop();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/scanai_hello_01.png'), context);
    precacheImage(const AssetImage('assets/images/scanai_hello_02.png'), context);
    precacheImage(const AssetImage('assets/images/scanai_hello_03.png'), context);
    precacheImage(const AssetImage('assets/images/scanai_hello.png'), context);
    precacheImage(const AssetImage('assets/images/scanai_kdo.png'), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        String assetPath;
        if (!_isStarted) {
          assetPath = 'assets/images/scanai_hello_01.png';
        } else if (_isAnimationFinished) {
          assetPath = 'assets/images/scanai_hello_03.png'; // Land on requested frame
        } else {
          if (_controller.value < 0.33) {
            assetPath = 'assets/images/scanai_hello_01.png';
          } else if (_controller.value < 0.66) {
            assetPath = 'assets/images/scanai_hello_02.png';
          } else {
            assetPath = 'assets/images/scanai_hello_03.png';
          }
        }

        return Image.asset(
          assetPath,
          height: widget.height,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          gaplessPlayback: true,
        );
      },
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


class _BentoInteractiveWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BentoInteractiveWrapper({
    required this.child,
    this.onTap,
  });

  @override
  State<_BentoInteractiveWrapper> createState() => _BentoInteractiveWrapperState();
}

class _BentoInteractiveWrapperState extends State<_BentoInteractiveWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  double _rotationX = 0.0;
  double _rotationY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    _controller.forward();
    
    // Tilt calculation based on touch position relative to center
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPos = details.localPosition;
    final centerX = box.size.width / 2;
    final centerY = box.size.height / 2;
    
    setState(() {
      // Sensitivity factor: 0.05
      _rotationX = (centerY - localPos.dy) / centerY * 0.08;
      _rotationY = (localPos.dx - centerX) / centerX * 0.08;
    });
    
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() {
      _rotationX = 0.0;
      _rotationY = 0.0;
    });
  }

  void _handleTapCancel() {
    _controller.reverse();
    setState(() {
      _rotationX = 0.0;
      _rotationY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateX(_rotationX)
              ..rotateY(_rotationY)
              ..scale(_scaleAnimation.value),
            child: child,
          );
        },
        child: widget.child,
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

  const _ShakeableWrapper({
    required this.child,
    required this.onTap,
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
    return GestureDetector(
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

class _BouncingWidget extends StatefulWidget {
  final Widget child;
  const _BouncingWidget({required this.child});

  @override
  State<_BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<_BouncingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2), // Faster, more lively pulse
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.92, end: 1.08).animate(
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
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}


class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _BubbleTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Triangular path with rounded tip using a quadratic bezier
    final path = Path();
    path.moveTo(0, 0);                 
    path.quadraticBezierTo(size.width * 1.2, size.height / 2, 0, size.height); // Much rounder, more friendly tip
    path.close();

    // 1. Shadow for the tail to match the card
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.03)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(2, 4)), shadowPaint);

    // 2. Main fill
    canvas.drawPath(path, paint);

    // 3. More visible border stroke
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.quadraticBezierTo(size.width * 1.2, size.height / 2, 0, size.height);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
