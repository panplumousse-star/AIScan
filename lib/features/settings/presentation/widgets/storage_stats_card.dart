import 'package:flutter/material.dart';

import '../../../../core/widgets/bento_card.dart';
import '../../../settings/domain/storage_stats.dart';

/// A Bento-style card that displays storage statistics.
///
/// Shows document count, documents size, thumbnails size, temp files size,
/// and total storage usage in a visually appealing format consistent with
/// the app's design language.
class StorageStatsCard extends StatelessWidget {
  /// Creates a [StorageStatsCard] with the given storage stats and theme.
  const StorageStatsCard({
    super.key,
    required this.stats,
    required this.isDark,
  });

  /// The storage statistics to display.
  final StorageStats? stats;

  /// Whether dark mode is active.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      borderRadius: 32,
      padding: const EdgeInsets.all(24),
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.6)
          : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.storage_rounded,
                  color: isDark
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Stockage',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (stats == null)
            _buildLoadingIndicator()
          else ...[
            _buildStatRow(
              Icons.description_outlined,
              'Documents',
              '${stats!.documentCount}',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              Icons.insert_drive_file_outlined,
              'Taille documents',
              stats!.formattedDocumentsSize,
              isDark,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              Icons.image_outlined,
              'Miniatures',
              stats!.formattedThumbnailsSize,
              isDark,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              Icons.schedule_outlined,
              'Fichiers temporaires',
              stats!.formattedTempSize,
              isDark,
            ),
            const SizedBox(height: 16),
            Divider(
              color: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              height: 1,
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              Icons.folder_outlined,
              'Total',
              stats!.formattedTotalSize,
              isDark,
              isTotal: true,
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a loading indicator for when stats are not yet available.
  Widget _buildLoadingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single statistic row.
  Widget _buildStatRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1))
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E1B4B),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }
}
