import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../folders/domain/folder_model.dart';

/// Section displaying folders in a paginated 2x4 grid layout.
class FoldersSection extends StatefulWidget {
  const FoldersSection({
    super.key,
    required this.folders,
    required this.selectedFolderIds,
    required this.isSelectionMode,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onCreateFolder,
    required this.theme,
  });

  final List<Folder> folders;
  final Set<String> selectedFolderIds;
  final bool isSelectionMode;
  final void Function(Folder) onFolderTap;
  final void Function(Folder) onFolderLongPress;
  final VoidCallback onCreateFolder;
  final ThemeData theme;

  @override
  State<FoldersSection> createState() => _FoldersSectionState();
}

class _FoldersSectionState extends State<FoldersSection> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Dossiers',
            style: TextStyle(fontFamily: 'Outfit', 
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.theme.colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            // +1 pour le bouton d'ajout sur la première page
            itemCount: ((widget.folders.length + 1) / 8).ceil(),
            itemBuilder: (context, pageIndex) {
              // Sur la première page, on a le bouton + puis les dossiers
              // Sur les autres pages, juste les dossiers
              final totalItemsWithButton = widget.folders.length + 1;
              final startIndex = pageIndex * 8;
              final endIndex = min(startIndex + 8, totalItemsWithButton);
              final itemsOnThisPage = endIndex - startIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: itemsOnThisPage,
                  itemBuilder: (context, index) {
                    final globalIndex = startIndex + index;

                    // Premier élément = bouton d'ajout
                    if (globalIndex == 0) {
                      return AddFolderButton(
                        onTap: widget.onCreateFolder,
                        theme: widget.theme,
                      );
                    }

                    // Les autres = dossiers (index - 1 car le bouton prend la place 0)
                    final folderIndex = globalIndex - 1;
                    final folder = widget.folders[folderIndex];
                    final isSelected =
                        widget.selectedFolderIds.contains(folder.id);
                    return FolderCard(
                      folder: folder,
                      isSelected: isSelected,
                      isSelectionMode: widget.isSelectionMode,
                      onTap: () => widget.onFolderTap(folder),
                      onLongPress: () => widget.onFolderLongPress(folder),
                      theme: widget.theme,
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Page indicator dots (only show if multiple pages)
        if (((widget.folders.length + 1) / 8).ceil() > 1)
          PageIndicatorDots(
            totalPages: ((widget.folders.length + 1) / 8).ceil(),
            currentPage: _currentPage,
            theme: widget.theme,
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Documents',
            style: TextStyle(fontFamily: 'Outfit', 
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Button to add a new folder.
class AddFolderButton extends StatelessWidget {
  const AddFolderButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.primary.withValues(alpha: 0.15)
                : colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.newFolder ?? 'New',
                style: TextStyle(fontFamily: 'Outfit', 
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual folder card widget.
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.folder,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.theme,
  });

  final Folder folder;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ThemeData theme;

  Color _parseColor(String? hexColor) {
    if (hexColor == null) return theme.colorScheme.secondary;
    try {
      final hex = hexColor.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } on Object catch (_) {
      return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderColor = _parseColor(folder.color);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: folderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      Icons.folder,
                      color: folderColor,
                      size: 28,
                    ),
                  ),
                  // Selection indicator (only in selection mode)
                  if (isSelectionMode)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                size: 14,
                                color: colorScheme.onPrimary,
                              )
                            : null,
                      ),
                    ),
                  // Favorite indicator (show heart if favorite)
                  if (folder.isFavorite && !isSelectionMode)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite_rounded,
                          size: 12,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                folder.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page indicator dots for multi-page navigation feedback.
class PageIndicatorDots extends StatelessWidget {
  const PageIndicatorDots({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.theme,
  });

  final int totalPages;
  final int currentPage;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          totalPages,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == currentPage ? 16 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: index == currentPage
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
