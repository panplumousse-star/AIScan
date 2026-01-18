import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/camera_permission_service.dart';
import '../../../core/permissions/permission_dialog.dart';
import '../../../core/storage/document_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bento_card.dart';
import '../../documents/presentation/documents_screen.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// Provider that checks if there are any documents in storage.
final hasDocumentsProvider = FutureProvider.autoDispose<bool>((ref) async {
  final repository = ref.read(documentRepositoryProvider);
  final documents = await repository.getAllDocuments();
  return documents.isNotEmpty;
});

/// Provider that gets recent document names for preview.
final recentDocumentsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final repository = ref.read(documentRepositoryProvider);
  final documents = await repository.getAllDocuments();
  // Get up to 3 most recent document names
  final sorted = documents.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(3).map((d) => d.title).toList();
});

/// Bento-style home screen with pastel cards and animations.
class BentoHomeScreen extends ConsumerWidget {
  const BentoHomeScreen({super.key});

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

  Future<void> _navigateToScanner(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final hasPermission = await _checkAndRequestPermission(context, ref);
    if (hasPermission && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ScannerScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDocuments = ref.watch(hasDocumentsProvider);
    final recentDocs = ref.watch(recentDocumentsProvider);

    return Scaffold(
      backgroundColor: AppColors.bentoBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Card 1: Header with mascot
              BentoAnimatedEntry(
                delay: const Duration(milliseconds: 0),
                child: _buildHeaderCard(context),
              ),

              const SizedBox(height: 16),

              // Card 2: Scanner
              BentoAnimatedEntry(
                delay: const Duration(milliseconds: 100),
                child: _buildScannerCard(context, ref),
              ),

              const SizedBox(height: 16),

              // Card 3: My Documents (only if documents exist)
              hasDocuments.when(
                data: (hasDocs) {
                  if (!hasDocs) return const SizedBox.shrink();
                  return BentoAnimatedEntry(
                    delay: const Duration(milliseconds: 200),
                    child: _buildDocumentsCard(
                      context,
                      ref,
                      recentDocs.valueOrNull ?? [],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Card 1: Header with background image and Scanaï logo
  Widget _buildHeaderCard(BuildContext context) {
    return BentoAnimatedEntry(
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: AppGradients.premiumCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    'assets/images/bento_entete.png',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.bentoBluePastel,
                      );
                    },
                  ),
                ),
              ),
              // Text overlay
              Positioned(
                left: 24,
                top: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, je suis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Scanaï logo
                    Image.asset(
                      'assets/images/scanai_name.png',
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          'Scanaï',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Prêt à scanner un document ?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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
  /// Card 2: Scanner action card with background image
  Widget _buildScannerCard(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _navigateToScanner(context, ref),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: AppGradients.scanner,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Opacity(
                  opacity: 0.6,
                  child: Image.asset(
                    'assets/images/scanner_start_page.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container();
                    },
                  ),
                ),
              ),
              // Content overlay with padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scanner un document',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Un seul tap, je m\'occupe du reste',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.primaryLight,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Scanner',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
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

  /// Card 3: My Documents preview
  Widget _buildDocumentsCard(
    BuildContext context,
    WidgetRef ref,
    List<String> recentDocNames,
  ) {
    return BentoCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (navContext) => DocumentsScreen(
              onScanPressed: () => _navigateToScanner(navContext, ref),
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/icone_documents.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bentoOrangePastel.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      color: Colors.orange[700],
                      size: 24,
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mes documents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
          if (recentDocNames.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Recent documents preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.flash_on,
                    color: Colors.orange[600],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      recentDocNames.join(' • '),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
