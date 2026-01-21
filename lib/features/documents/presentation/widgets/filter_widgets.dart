import 'package:flutter/material.dart';

import '../models/documents_ui_models.dart';

/// A chip displaying an active filter with a clear button.
///
/// Used to show individual active filters in a compact horizontal bar.
/// Tapping the chip invokes the onClear callback.
///
/// ## Usage
/// ```dart
/// ActiveFilterChip(
///   label: 'Favorites',
///   icon: Icons.favorite,
///   onClear: () => notifier.clearFavorites(),
/// )
/// ```
class ActiveFilterChip extends StatelessWidget {
  /// Creates an [ActiveFilterChip] with the given label and clear callback.
  const ActiveFilterChip({
    super.key,
    required this.label,
    required this.onClear,
    this.icon,
    this.color,
  });

  /// The label text to display on the chip.
  final String label;

  /// Optional icon to display before the label.
  final IconData? icon;

  /// Optional color for the chip.
  final Color? color;

  /// Callback when the clear button is tapped.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chipColor = color ?? colorScheme.primaryContainer;

    return Chip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 18,
              color: colorScheme.onPrimaryContainer,
            )
          : null,
      label: Text(label),
      deleteIcon: Icon(
        Icons.close,
        size: 18,
        color: colorScheme.onPrimaryContainer,
      ),
      onDeleted: onClear,
      backgroundColor: chipColor,
      labelStyle: TextStyle(
        color: colorScheme.onPrimaryContainer,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// A chip displaying the current sort option.
///
/// Shows the sort icon and label in a compact format.
/// Can be tapped to open the sort/filter sheet.
///
/// ## Usage
/// ```dart
/// SortByChip(
///   sortBy: DocumentsSortBy.createdDesc,
///   onTap: () => showFilterSheet(context),
/// )
/// ```
class SortByChip extends StatelessWidget {
  /// Creates a [SortByChip] with the current sort option.
  const SortByChip({
    super.key,
    required this.sortBy,
    this.onTap,
  });

  /// The current sort option.
  final DocumentsSortBy sortBy;

  /// Optional callback when the chip is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ActionChip(
      avatar: Icon(
        sortBy.icon,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
      label: Text(sortBy.label),
      onPressed: onTap,
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// A horizontal bar displaying all active filters and sort option.
///
/// Shows chips for each active filter with clear buttons, the current sort,
/// and a "Clear all" button when filters are active.
///
/// ## Usage
/// ```dart
/// FilterSummaryBar(
///   sortBy: state.sortBy,
///   filter: state.filter,
///   folderName: 'Work Documents',
///   tagNames: ['Important', 'Review'],
///   onClearSort: () => notifier.setSortBy(DocumentsSortBy.createdDesc),
///   onClearFolder: () => notifier.clearFolderFilter(),
///   onClearTag: (tagId) => notifier.removeTagFilter(tagId),
///   onClearFavorites: () => notifier.clearFavoritesFilter(),
///   onClearOcr: () => notifier.clearOcrFilter(),
///   onClearAll: () => notifier.clearAllFilters(),
///   onSortTap: () => showFilterSheet(context),
/// )
/// ```
class FilterSummaryBar extends StatelessWidget {
  /// Creates a [FilterSummaryBar] with the current filters and callbacks.
  const FilterSummaryBar({
    super.key,
    required this.sortBy,
    required this.filter,
    this.folderName,
    this.tagNames = const {},
    this.onClearSort,
    this.onClearFolder,
    this.onClearTag,
    this.onClearFavorites,
    this.onClearOcr,
    this.onClearAll,
    this.onSortTap,
  });

  /// The current sort option.
  final DocumentsSortBy sortBy;

  /// The current filter settings.
  final DocumentsFilter filter;

  /// The name of the filtered folder, if any.
  final String? folderName;

  /// Map of tag IDs to tag names for active tag filters.
  final Map<String, String> tagNames;

  /// Callback to clear the sort (reset to default).
  final VoidCallback? onClearSort;

  /// Callback to clear the folder filter.
  final VoidCallback? onClearFolder;

  /// Callback to clear a specific tag filter.
  final void Function(String tagId)? onClearTag;

  /// Callback to clear the favorites filter.
  final VoidCallback? onClearFavorites;

  /// Callback to clear the OCR filter.
  final VoidCallback? onClearOcr;

  /// Callback to clear all filters.
  final VoidCallback? onClearAll;

  /// Callback when the sort chip is tapped.
  final VoidCallback? onSortTap;

  bool get _hasActiveFilters =>
      filter.hasActiveFilters || sortBy != DocumentsSortBy.createdDesc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final chips = <Widget>[];

    // Add sort chip (always shown)
    chips.add(
      SortByChip(
        sortBy: sortBy,
        onTap: onSortTap,
      ),
    );

    // Add folder filter chip
    if (filter.folderId != null && folderName != null) {
      chips.add(
        ActiveFilterChip(
          label: folderName!,
          icon: Icons.folder,
          onClear: onClearFolder ?? () {},
        ),
      );
    }

    // Add favorites filter chip
    if (filter.favoritesOnly) {
      chips.add(
        ActiveFilterChip(
          label: 'Favorites',
          icon: Icons.favorite,
          color: colorScheme.errorContainer,
          onClear: onClearFavorites ?? () {},
        ),
      );
    }

    // Add OCR filter chip
    if (filter.hasOcrOnly) {
      chips.add(
        ActiveFilterChip(
          label: 'Has OCR',
          icon: Icons.text_fields,
          color: colorScheme.tertiaryContainer,
          onClear: onClearOcr ?? () {},
        ),
      );
    }

    // Add tag filter chips
    for (final tagId in filter.tagIds) {
      final tagName = tagNames[tagId] ?? 'Unknown';
      chips.add(
        ActiveFilterChip(
          label: tagName,
          icon: Icons.label,
          onClear: onClearTag != null ? () => onClearTag!(tagId) : () {},
        ),
      );
    }

    // Add clear all button if there are active filters
    if (_hasActiveFilters && onClearAll != null) {
      chips.add(
        TextButton.icon(
          onPressed: onClearAll,
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Clear all'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              chips[i],
              if (i < chips.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// A button for quick filter toggles (favorites, OCR).
///
/// Shows an icon with a badge when the filter is active.
/// Used in app bars or toolbars for quick access to common filters.
///
/// ## Usage
/// ```dart
/// QuickFilterButton(
///   icon: Icons.favorite,
///   isActive: state.filter.favoritesOnly,
///   onPressed: () => notifier.toggleFavorites(),
///   tooltip: 'Favorites only',
/// )
/// ```
class QuickFilterButton extends StatelessWidget {
  /// Creates a [QuickFilterButton] with the given icon and state.
  const QuickFilterButton({
    super.key,
    required this.icon,
    required this.isActive,
    required this.onPressed,
    this.tooltip,
    this.activeColor,
  });

  /// The icon to display.
  final IconData icon;

  /// Whether this filter is currently active.
  final bool isActive;

  /// Callback when the button is pressed.
  final VoidCallback onPressed;

  /// Optional tooltip text.
  final String? tooltip;

  /// Optional color when active.
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final buttonColor = isActive
        ? (activeColor ?? colorScheme.primary)
        : colorScheme.onSurfaceVariant;

    final button = IconButton(
      icon: Icon(icon),
      onPressed: onPressed,
      color: buttonColor,
      tooltip: tooltip,
    );

    if (!isActive) {
      return button;
    }

    // Show badge when active
    return Badge(
      backgroundColor: activeColor ?? colorScheme.primary,
      smallSize: 8,
      child: button,
    );
  }
}

/// A compact filter button that opens the filter sheet.
///
/// Shows a badge with the number of active filters.
/// Used in app bars or toolbars.
///
/// ## Usage
/// ```dart
/// FilterButton(
///   activeFilterCount: state.filter.activeFilterCount,
///   onPressed: () => showFilterSheet(context),
/// )
/// ```
class FilterButton extends StatelessWidget {
  /// Creates a [FilterButton] with the active filter count.
  const FilterButton({
    super.key,
    required this.activeFilterCount,
    required this.onPressed,
    this.tooltip = 'Sort & Filter',
  });

  /// Number of currently active filters (not including sort).
  final int activeFilterCount;

  /// Callback when the button is pressed.
  final VoidCallback onPressed;

  /// Tooltip text.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (activeFilterCount == 0) {
      return IconButton(
        icon: const Icon(Icons.filter_list),
        onPressed: onPressed,
        tooltip: tooltip,
      );
    }

    return Badge(
      label: Text('$activeFilterCount'),
      backgroundColor: colorScheme.primary,
      textColor: colorScheme.onPrimary,
      child: IconButton(
        icon: const Icon(Icons.filter_list),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
