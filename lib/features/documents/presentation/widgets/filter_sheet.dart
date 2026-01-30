import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../folders/domain/folder_model.dart';
import '../../../folders/domain/folder_service.dart';
import '../models/documents_ui_models.dart';

/// A provider for loading folders for the filter sheet.
final _filterFoldersProvider =
    FutureProvider.autoDispose<List<Folder>>((ref) async {
  final folderService = ref.watch(folderServiceProvider);
  try {
    await folderService.initialize();
    return folderService.getAllFolders();
  } on Object catch (_) {
    return [];
  }
});

/// Bottom sheet widget for sorting and filtering documents.
///
/// Provides options for:
/// - Sorting by date, name, size, etc.
/// - Filtering by folder
/// - Filtering by favorites and OCR status
///
/// ## Usage
/// ```dart
/// await showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (context) => FilterSheet(
///     currentSortBy: state.sortBy,
///     currentFilter: state.filter,
///     onSortByChanged: notifier.setSortBy,
///     onFilterChanged: notifier.setFilter,
///   ),
/// );
/// ```
class FilterSheet extends ConsumerStatefulWidget {
  /// Creates a [FilterSheet] with the current sort and filter state.
  const FilterSheet({
    super.key,
    required this.currentSortBy,
    required this.currentFilter,
    required this.onSortByChanged,
    required this.onFilterChanged,
  });

  /// The current sort option.
  final DocumentsSortBy currentSortBy;

  /// The current filter settings.
  final DocumentsFilter currentFilter;

  /// Callback when sort option changes.
  final void Function(DocumentsSortBy) onSortByChanged;

  /// Callback when filter settings change.
  final void Function(DocumentsFilter) onFilterChanged;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late DocumentsSortBy _selectedSort;
  late DocumentsFilter _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.currentSortBy;
    _selectedFilter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header with title and actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      l10n?.sortAndFilter ?? 'Sort & Filter',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_hasActiveFilters)
                      TextButton(
                        onPressed: _clearAllFilters,
                        child: Text(l10n?.clearAll ?? 'Clear all'),
                      ),
                  ],
                ),
              ),
              const Divider(),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Sort section
                    _buildSectionHeader(
                        context, l10n?.sortBy ?? 'Sort by', Icons.sort),
                    const SizedBox(height: 8),
                    _buildSortOptions(context),
                    const SizedBox(height: 24),

                    // Quick filters section
                    _buildSectionHeader(
                        context,
                        l10n?.quickFilters ?? 'Quick Filters',
                        Icons.filter_list),
                    const SizedBox(height: 8),
                    _buildQuickFilters(context, l10n),
                    const SizedBox(height: 24),

                    // Folder filter section
                    _buildSectionHeader(context, l10n?.folder ?? 'Folder',
                        Icons.folder_outlined),
                    const SizedBox(height: 8),
                    _buildFolderFilter(context, l10n),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // Apply button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _applyChanges,
                      child: Text(l10n?.apply ?? 'Apply'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSortOptions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DocumentsSortBy.values.map((sort) {
        final isSelected = _selectedSort == sort;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sort.icon,
                size: 18,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(sort.label),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedSort = sort;
              });
            }
          },
          selectedColor: colorScheme.primaryContainer,
          labelStyle: TextStyle(
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickFilters(BuildContext context, AppLocalizations? l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Favorites filter
        _buildFilterTile(
          context: context,
          title: l10n?.favoritesOnly ?? 'Favorites only',
          subtitle: l10n?.favoritesOnlyDescription ??
              'Show only documents marked as favorite',
          icon: Icons.favorite,
          iconColor: colorScheme.error,
          isSelected: _selectedFilter.favoritesOnly,
          onChanged: (value) {
            setState(() {
              _selectedFilter = _selectedFilter.copyWith(favoritesOnly: value);
            });
          },
        ),
        const SizedBox(height: 8),
        // OCR filter
        _buildFilterTile(
          context: context,
          title: l10n?.hasOcrText ?? 'Has OCR text',
          subtitle: l10n?.hasOcrTextDescription ??
              'Show only documents with extracted text',
          icon: Icons.text_fields,
          iconColor: colorScheme.tertiary,
          isSelected: _selectedFilter.hasOcrOnly,
          onChanged: (value) {
            setState(() {
              _selectedFilter = _selectedFilter.copyWith(hasOcrOnly: value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildFilterTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required void Function(bool) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isSelected,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderFilter(BuildContext context, AppLocalizations? l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foldersAsync = ref.watch(_filterFoldersProvider);

    return foldersAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => Text(
        l10n?.failedToLoadFolders ?? 'Failed to load folders',
        style: TextStyle(color: colorScheme.error),
      ),
      data: (folders) {
        if (folders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_off_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n?.noFoldersYet ?? 'No folders created yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // All documents option
            _buildFolderOption(
              context: context,
              title: l10n?.allDocumentsFilter ?? 'All Documents',
              icon: Icons.folder_open,
              isSelected: _selectedFilter.folderId == null,
              onTap: () {
                setState(() {
                  _selectedFilter =
                      _selectedFilter.copyWith(clearFolderId: true);
                });
              },
            ),
            const SizedBox(height: 4),
            // Folder list
            ...folders.sortedByName().map((folder) {
              final isSelected = _selectedFilter.folderId == folder.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _buildFolderOption(
                  context: context,
                  title: folder.name,
                  icon: Icons.folder,
                  color: AppTheme.parseColor(folder.color),
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedFilter =
                            _selectedFilter.copyWith(clearFolderId: true);
                      } else {
                        _selectedFilter =
                            _selectedFilter.copyWith(folderId: folder.id);
                      }
                    });
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildFolderOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = color ?? colorScheme.primary;

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _selectedFilter.hasActiveFilters ||
      _selectedSort != DocumentsSortBy.createdDesc;

  void _clearAllFilters() {
    setState(() {
      _selectedSort = DocumentsSortBy.createdDesc;
      _selectedFilter = const DocumentsFilter();
    });
  }

  void _applyChanges() {
    // Apply sort if changed
    if (_selectedSort != widget.currentSortBy) {
      widget.onSortByChanged(_selectedSort);
    }
    // Apply filter if changed
    if (_selectedFilter != widget.currentFilter) {
      widget.onFilterChanged(_selectedFilter);
    }
    // Close the sheet
    Navigator.of(context).pop();
  }

}

/// Shows the filter bottom sheet.
///
/// Returns `true` if changes were applied, `false` if dismissed.
Future<bool?> showFilterSheet({
  required BuildContext context,
  required DocumentsSortBy currentSortBy,
  required DocumentsFilter currentFilter,
  required void Function(DocumentsSortBy) onSortByChanged,
  required void Function(DocumentsFilter) onFilterChanged,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FilterSheet(
      currentSortBy: currentSortBy,
      currentFilter: currentFilter,
      onSortByChanged: onSortByChanged,
      onFilterChanged: onFilterChanged,
    ),
  );
}
