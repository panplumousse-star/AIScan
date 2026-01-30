import 'dart:math';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
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

  /// Détermine si on affiche une seule ligne (≤4 dossiers) ou deux lignes (>4 dossiers)
  bool get _isSingleRow => widget.folders.length <= 3; // +1 pour le bouton = 4 max

  /// Nombre d'éléments par page selon le mode (4 pour une ligne, 8 pour deux lignes)
  int get _itemsPerPage => _isSingleRow ? 4 : 8;

  /// Hauteur de la section selon le mode
  double get _sectionHeight => _isSingleRow ? 70.0 : 145.0;

  @override
  Widget build(BuildContext context) {
    final totalItemsWithButton = widget.folders.length + 1;
    final totalPages = (totalItemsWithButton / _itemsPerPage).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            'Dossiers',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: widget.theme.colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: _sectionHeight,
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            itemBuilder: (context, pageIndex) {
              // Sur la première page, on a le bouton + puis les dossiers
              // Sur les autres pages, juste les dossiers
              final startIndex = pageIndex * _itemsPerPage;
              final endIndex = min(startIndex + _itemsPerPage, totalItemsWithButton);
              final itemsOnThisPage = endIndex - startIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 4,
                    childAspectRatio: _isSingleRow ? 1.2 : 1.15,
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
        if (totalPages > 1)
          PageIndicatorDots(
            totalPages: totalPages,
            currentPage: _currentPage,
            theme: widget.theme,
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Documents',
            style: TextStyle(
              fontFamily: 'Outfit',
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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.primary.withValues(alpha: 0.15)
                      : colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n?.newFolder ?? 'New',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 10,
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

  @override
  Widget build(BuildContext context) {
    final folderColor =
        AppTheme.parseColor(folder.color) ?? theme.colorScheme.secondary;
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: folderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      Icons.folder,
                      color: folderColor,
                      size: 24,
                    ),
                  ),
                  // Selection indicator (only in selection mode)
                  if (isSelectionMode)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 17,
                        height: 17,
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
                                size: 12,
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
                          size: 10,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
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
