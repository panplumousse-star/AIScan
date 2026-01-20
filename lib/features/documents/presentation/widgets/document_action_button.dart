import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// An action button for the document detail bottom action bar.
///
/// This button displays an icon, label, optional badge, and can be styled
/// as a primary action with a gradient background. It follows the Bento
/// design system with proper spacing and visual feedback.
///
/// ## Usage
/// ```dart
/// DocumentActionButton(
///   icon: Icons.share_rounded,
///   label: 'Partager',
///   onPressed: () => _handleShare(context),
///   theme: theme,
/// )
/// ```
///
/// For primary actions with gradient styling:
/// ```dart
/// DocumentActionButton(
///   icon: Icons.auto_fix_high_rounded,
///   label: 'Magie',
///   onPressed: () => _handleEnhance(context),
///   theme: theme,
///   isPrimary: true,
/// )
/// ```
///
/// With a notification badge:
/// ```dart
/// DocumentActionButton(
///   icon: Icons.text_snippet_rounded,
///   label: 'OCR',
///   onPressed: () => _handleOcr(context),
///   badge: '!',
///   theme: theme,
/// )
/// ```
class DocumentActionButton extends StatelessWidget {
  /// Creates a [DocumentActionButton].
  const DocumentActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.theme,
    this.badge,
    this.isPrimary = false,
  });

  /// The icon to display at the top of the button.
  final IconData icon;

  /// The text label displayed below the icon.
  final String label;

  /// Callback invoked when the button is pressed.
  final VoidCallback onPressed;

  /// The theme data used for styling.
  ///
  /// Used to determine colors based on light/dark mode.
  final ThemeData theme;

  /// Optional badge text displayed on the icon (e.g., '!' for notifications).
  ///
  /// When present, displays a small red circular badge at the top-right
  /// of the icon.
  final String? badge;

  /// Whether this button should be styled as a primary action.
  ///
  /// Primary actions receive a gradient background and elevated appearance.
  /// Defaults to false.
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: isPrimary ? BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF312E81), const Color(0xFF3730A3)]
                    : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF4F46E5)).withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isPrimary
                          ? Colors.white
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    if (badge != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                    color: isPrimary
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
