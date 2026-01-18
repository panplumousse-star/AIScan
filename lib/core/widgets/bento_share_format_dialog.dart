import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/sharing/domain/document_share_service.dart';
import 'bento_card.dart';

/// A reusable dialog for selecting share format (PDF or Images).
///
/// Features a mascot with speech bubble saying "J'envoie !" and
/// presents two options: PDF (compressed single document) or
/// Images (original quality PNG).
///
/// Usage:
/// ```dart
/// final format = await showBentoShareFormatDialog(context);
/// if (format != null) {
///   // User selected a format
/// }
/// ```
Future<ShareFormat?> showBentoShareFormatDialog(BuildContext context) {
  return showDialog<ShareFormat>(
    context: context,
    builder: (context) => const BentoShareFormatDialog(),
  );
}

class BentoShareFormatDialog extends StatelessWidget {
  const BentoShareFormatDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: BentoCard(
              padding: const EdgeInsets.all(24),
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mascot with speech bubble
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Mascot image
                      Image.asset(
                        'assets/images/scanai_share.png',
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      // Speech bubble
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : const Color(0xFFEEF2FF),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'J\'envoie !',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1B4B),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -6,
                                left: 8,
                                child: CustomPaint(
                                  size: const Size(10, 10),
                                  painter: _BubbleTailPainter(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : const Color(0xFFEEF2FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Partager au format',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ShareOptionTile(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'PDF',
                    subtitle: 'Document unique compressé',
                    color: Colors.redAccent,
                    onTap: () => Navigator.pop(context, ShareFormat.pdf),
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _ShareOptionTile(
                    icon: Icons.image_rounded,
                    title: 'Images',
                    subtitle: 'Qualité originale (PNG)',
                    color: const Color(0xFF4F46E5),
                    onTap: () => Navigator.pop(context, ShareFormat.images),
                    theme: theme,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.outfit(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
}

class _ShareOptionTile extends StatelessWidget {
  const _ShareOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter for speech bubble tail pointing toward mascot on the left.
class _BubbleTailPainter extends CustomPainter {
  final Color color;

  _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw tail pointing down-left (toward mascot on the left)
    final path = Path();
    path.moveTo(size.width, 0); // Top right (connected to bubble)
    path.lineTo(0, size.height); // Bottom left (pointing to mascot)
    path.lineTo(size.width, size.height * 0.6); // Right side
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
