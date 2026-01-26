import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../models/documents_ui_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bento_card.dart';
import '../../../../l10n/app_localizations.dart';

/// Bento-style header card showing document statistics.
class BentoStatsHeader extends StatelessWidget {
  const BentoStatsHeader({
    super.key,
    required this.documentCount,
    required this.folderCount,
    this.lastUpdated,
  });

  final int documentCount;
  final int folderCount;
  final DateTime? lastUpdated;

  String _formatLastUpdated(AppLocalizations? l10n) {
    if (lastUpdated == null) return '';
    final now = DateTime.now();
    final diff = now.difference(lastUpdated!);

    if (diff.inMinutes < 1) {
      return l10n?.justNow ?? 'Just now';
    }
    if (diff.inMinutes < 60) {
      return l10n?.minutesAgo(diff.inMinutes) ?? '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return l10n?.hoursAgo(diff.inHours) ?? '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return l10n?.daysAgo(diff.inDays) ?? '${diff.inDays} days ago';
    }
    return '${lastUpdated!.day}/${lastUpdated!.month}/${lastUpdated!.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return BentoCard(
      blur: 10,
      backgroundColor: isDark
          ? const Color(0xFF000000).withValues(alpha: 0.4)
          : Colors.white.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.description_outlined,
                      label: l10n?.nDocumentsLabel(documentCount) ??
                          '$documentCount documents',
                      color: isDark
                          ? const Color(0xFF93C5FD)
                          : AppColors.bentoButtonBlue,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.folder_outlined,
                      label: l10n?.nFoldersLabel(folderCount) ??
                          '$folderCount folders',
                      color: isDark
                          ? const Color(0xFFFDBA74)
                          : Colors.orange[700]!,
                      isDark: isDark,
                    ),
                  ],
                ),
                if (lastUpdated != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${l10n?.lastUpdated ?? 'Last updated'}: ${_formatLastUpdated(l10n)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: 28,
              color:
                  isDark ? const Color(0xFF93C5FD) : AppColors.bentoButtonBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : color.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bento-style search bar with pastel background.
/// Bento-style search bar with animated controls.
class BentoSearchBar extends StatefulWidget {
  const BentoSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onToggleViewMode,
    required this.onShowFilters,
    required this.onToggleFavorites,
    required this.viewMode,
    required this.isFavoritesOnly,
    required this.hasActiveFilters,
    required this.isSelectionMode,
    required this.selectedCount,
    required this.selectedDocumentCount,
    required this.selectedFolderCount,
    required this.hasDocumentsSelected,
    required this.onDeleteSelected,
    required this.onFavoriteSelected,
    required this.onShareSelected,
    required this.onExportSelected,
    required this.onMoveSelected,
    this.hasText = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onToggleViewMode;
  final VoidCallback onShowFilters;
  final VoidCallback onToggleFavorites;
  final DocumentsViewMode viewMode;
  final bool isFavoritesOnly;
  final bool hasActiveFilters;
  final bool hasText;
  final FocusNode? focusNode;

  // Selection props
  final bool isSelectionMode;
  final int selectedCount;
  final int selectedDocumentCount;
  final int selectedFolderCount;
  final bool hasDocumentsSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onFavoriteSelected;
  final VoidCallback onShareSelected;
  final VoidCallback onExportSelected;
  final VoidCallback onMoveSelected;

  @override
  State<BentoSearchBar> createState() => _BentoSearchBarState();
}

class _BentoSearchBarState extends State<BentoSearchBar>
    with SingleTickerProviderStateMixin {
  FocusNode? _internalFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;
  bool _isFocused = false;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _focusNode.addListener(_onFocusChange);

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    if (widget.isSelectionMode) {
      _flipController.value = 1;
    }
  }

  @override
  void didUpdateWidget(BentoSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelectionMode != oldWidget.isSelectionMode) {
      if (widget.isSelectionMode) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    }
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * 3.141592653589793;
          final isBack = angle > 3.141592653589793 / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(angle),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateX(isBack ? 3.141592653589793 : 0),
              child: isBack
                  ? _buildSelectionSide(isDark, theme)
                  : _buildSearchSide(isDark, theme),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchSide(bool isDark, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return BentoCard(
      height: 56,
      blur: 15,
      borderRadius: 20,
      padding: EdgeInsets.zero,
      backgroundColor: isDark
          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
          : const Color(0xFFF1F5F9).withValues(alpha: 0.8),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: TextStyle(
              fontFamily: 'Outfit',
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: l10n?.search ?? 'Search...',
                hintStyle: TextStyle(
              fontFamily: 'Outfit',
                  color: isDark ? Colors.white38 : Colors.grey[500],
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                suffixIcon: widget.hasText
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                        onPressed: widget.onClear,
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isFocused ? 0 : 130,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ControlIcon(
                    icon: widget.viewMode == DocumentsViewMode.grid
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    onPressed: widget.onToggleViewMode,
                  ),
                  _ControlIcon(
                    icon: Icons.tune_rounded,
                    color: widget.hasActiveFilters
                        ? theme.colorScheme.primary
                        : null,
                    onPressed: widget.onShowFilters,
                  ),
                  _ControlIcon(
                    icon: widget.isFavoritesOnly
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: widget.isFavoritesOnly ? Colors.redAccent : null,
                    onPressed: widget.onToggleFavorites,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _buildSelectionText(AppLocalizations? l10n) {
    final docs = widget.selectedDocumentCount;
    final folders = widget.selectedFolderCount;

    if (folders > 0 && docs > 0) {
      // Both types selected
      return l10n?.foldersAndDocs(folders, docs) ??
          '$folders folders, $docs documents';
    } else if (folders > 0) {
      // Only folders
      return l10n?.folderSelected(folders) ?? '$folders folders selected';
    } else {
      // Only documents
      return l10n?.documentSelected(docs) ?? '$docs documents selected';
    }
  }

  Widget _buildSelectionSide(bool isDark, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return BentoCard(
      height: 56,
      blur: 15,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundColor: theme.colorScheme.primaryContainer
          .withValues(alpha: isDark ? 0.3 : 0.8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${widget.selectedCount}',
              style: TextStyle(
              fontFamily: 'Outfit',
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _buildSelectionText(l10n),
              style: TextStyle(
              fontFamily: 'Outfit',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onPrimaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          // Favorite button - shown when documents OR folders are selected
          if (widget.hasDocumentsSelected || widget.selectedFolderCount > 0)
            _ControlIcon(
              icon: Icons.favorite_border_rounded,
              onPressed: widget.onFavoriteSelected,
              color: isDark
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onPrimaryContainer,
            ),
          // Share button - only for documents
          if (widget.hasDocumentsSelected)
            _ControlIcon(
              icon: Icons.share_rounded,
              onPressed: widget.onShareSelected,
              color: isDark
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onPrimaryContainer,
            ),
          // Export button - only for documents
          if (widget.hasDocumentsSelected)
            _ControlIcon(
              icon: Icons.save_alt_rounded,
              onPressed: widget.onExportSelected,
              color: isDark
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onPrimaryContainer,
            ),
          // Move button - only for documents
          if (widget.hasDocumentsSelected)
            _ControlIcon(
              icon: Icons.drive_file_move_outline,
              onPressed: widget.onMoveSelected,
              color: isDark
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onPrimaryContainer,
            ),
          _ControlIcon(
            icon: Icons.delete_outline_rounded,
            onPressed: widget.onDeleteSelected,
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  const _ControlIcon({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Bento-style folder card with pastel color.
class BentoFolderCard extends StatefulWidget {
  const BentoFolderCard({
    super.key,
    required this.name,
    required this.color,
    required this.documentCount,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  final String name;
  final Color color;
  final int documentCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  @override
  State<BentoFolderCard> createState() => _BentoFolderCardState();
}

class _BentoFolderCardState extends State<BentoFolderCard> {

  Color _getPastelColor() {
    // Convert folder color to pastel version
    final hsl = HSLColor.fromColor(widget.color);
    return hsl.withLightness(0.9).withSaturation(0.4).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pastelBg = _getPastelColor();
    final l10n = AppLocalizations.of(context);

    return RepaintBoundary(
      child: BentoCard(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        padding: EdgeInsets.zero,
        blur: 10,
        backgroundColor: widget.isSelected
            ? widget.color.withValues(alpha: 0.2)
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.7)),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pastelBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.folder_rounded,
                      size: 28,
                      color: widget.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.name,
                    style: TextStyle(
              fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.nDocs(widget.documentCount) ??
                        '${widget.documentCount} docs',
                    style: TextStyle(
              fontFamily: 'Outfit',
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            if (widget.isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color:
                        widget.isSelected ? widget.color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white24 : Colors.black12),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    widget.isSelected ? Icons.check : Icons.circle_outlined,
                    size: 14,
                    color: widget.isSelected
                        ? Colors.white
                        : (isDark ? Colors.white24 : Colors.black12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bento-style document card with rounded thumbnail.
class BentoDocumentCard extends StatefulWidget {
  const BentoDocumentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.thumbnailBytes,
    required this.onTap,
    required this.onLongPress,
    required this.onFavoriteToggle,
    this.isFavorite = false,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.pageCount = 1,
  });

  final String title;
  final String subtitle;
  final Uint8List? thumbnailBytes;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFavoriteToggle;
  final bool isFavorite;
  final bool isSelected;
  final bool isSelectionMode;
  final int pageCount;

  @override
  State<BentoDocumentCard> createState() => _BentoDocumentCardState();
}

class _BentoDocumentCardState extends State<BentoDocumentCard> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: BentoCard(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          padding: const EdgeInsets.all(12),
          blur: 8,
          backgroundColor: widget.isSelected
              ? AppColors.bentoButtonBlue.withValues(alpha: 0.15)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white.withValues(alpha: 0.6)),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 64,
                height: 76,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.thumbnailBytes != null
                    ? Image.memory(
                        widget.thumbnailBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
              fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
              fontFamily: 'Outfit',
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                l10n?.pageCount(widget.pageCount) ??
                                    '${widget.pageCount} page${widget.pageCount > 1 ? 's' : ''}',
                                style: TextStyle(
              fontFamily: 'Outfit',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                children: [
                  if (widget.isSelectionMode)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? AppColors.bentoButtonBlue
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isSelected
                              ? Colors.transparent
                              : (isDark ? Colors.white24 : Colors.black12),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        widget.isSelected ? Icons.check : Icons.circle_outlined,
                        size: 18,
                        color: widget.isSelected
                            ? Colors.white
                            : (isDark ? Colors.white24 : Colors.black12),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: widget.onFavoriteToggle,
                      icon: Icon(
                        widget.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: widget.isFavorite
                            ? Colors.red[400]
                            : (isDark ? Colors.white24 : Colors.grey[400]),
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
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

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.description_outlined,
        size: 28,
        color: Colors.grey[400],
      ),
    );
  }
}

/// Bento-style FAB for scanning.
///
/// Matches the app's design language with gradient background,
/// rounded corners, and subtle pulse animation.
class BentoScanFab extends StatefulWidget {
  const BentoScanFab({
    super.key,
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  State<BentoScanFab> createState() => _BentoScanFabState();
}

class _BentoScanFabState extends State<BentoScanFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                // Primary gradient glow
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: _glowAnimation.value),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                // Secondary blue glow
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: _glowAnimation.value * 0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(28),
                splashColor: Colors.white.withValues(alpha: 0.2),
                highlightColor: Colors.white.withValues(alpha: 0.1),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppGradients.scanner,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: isDark ? 0.2 : 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.document_scanner_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n?.scanner ?? 'Scan',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.3,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
