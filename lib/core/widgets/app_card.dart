import 'package:flutter/material.dart';

import '../accessibility/accessibility_config.dart';
import '../theme/app_theme.dart';

// ============================================================================
// App Card Variants
// ============================================================================

/// Card variant types for different visual styles.
enum AppCardVariant {
  /// Elevated card with shadow (default Material card).
  elevated,

  /// Filled card with background color, no shadow.
  filled,

  /// Outlined card with border, no shadow.
  outlined,
}

// ============================================================================
// App Card Widget
// ============================================================================

/// A reusable card widget with consistent styling across the app.
///
/// Provides multiple variants while maintaining Material Design 3 compliance
/// and accessibility support.
///
/// ## Usage
/// ```dart
/// // Basic elevated card
/// AppCard(
///   child: Padding(
///     padding: EdgeInsets.all(16),
///     child: Text('Card content'),
///   ),
/// )
///
/// // Tappable card
/// AppCard(
///   onTap: () => navigateToDetail(),
///   child: DocumentTile(document: doc),
/// )
///
/// // Outlined card variant
/// AppCard.outlined(
///   child: SettingsSection(),
/// )
///
/// // Card with custom semantics
/// AppCard(
///   semanticLabel: 'Document: Invoice 2024',
///   semanticHint: 'Double tap to open',
///   onTap: () => openDocument(),
///   child: DocumentPreview(),
/// )
/// ```
class AppCard extends StatelessWidget {
  /// Creates an [AppCard] with elevated variant (default).
  const AppCard({
    required this.child,
    this.variant = AppCardVariant.elevated,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.elevation,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
    this.semanticHint,
    this.isSelected = false,
    this.showSelectedBorder = true,
    super.key,
  });

  /// Creates an [AppCard] with elevated variant.
  const AppCard.elevated({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.elevation,
    this.borderRadius,
    this.backgroundColor,
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
    this.semanticHint,
    this.isSelected = false,
    this.showSelectedBorder = true,
    super.key,
  })  : variant = AppCardVariant.elevated,
        borderColor = null,
        borderWidth = null;

  /// Creates an [AppCard] with filled variant.
  const AppCard.filled({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
    this.semanticHint,
    this.isSelected = false,
    this.showSelectedBorder = true,
    super.key,
  })  : variant = AppCardVariant.filled,
        elevation = null,
        borderColor = null,
        borderWidth = null;

  /// Creates an [AppCard] with outlined variant.
  const AppCard.outlined({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
    this.semanticHint,
    this.isSelected = false,
    this.showSelectedBorder = true,
    super.key,
  })  : variant = AppCardVariant.outlined,
        elevation = null;

  /// The card's content.
  final Widget child;

  /// The visual style variant.
  final AppCardVariant variant;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  /// Callback when the card is long-pressed.
  final VoidCallback? onLongPress;

  /// Padding around the card content.
  final EdgeInsetsGeometry? padding;

  /// Margin around the card.
  final EdgeInsetsGeometry? margin;

  /// Elevation for elevated variant.
  final double? elevation;

  /// Border radius override.
  final BorderRadius? borderRadius;

  /// Background color override.
  final Color? backgroundColor;

  /// Border color for outlined variant.
  final Color? borderColor;

  /// Border width for outlined variant.
  final double? borderWidth;

  /// Clip behavior for child content.
  final Clip clipBehavior;

  /// Semantic label for screen readers.
  final String? semanticLabel;

  /// Semantic hint for screen readers.
  final String? semanticHint;

  /// Whether the card is in selected state.
  final bool isSelected;

  /// Whether to show a border when selected.
  final bool showSelectedBorder;

  /// Whether the card is interactive.
  bool get _isInteractive => onTap != null || onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine effective values
    final effectiveBorderRadius = borderRadius ?? AppBorderRadius.card;
    final effectiveMargin = margin ?? const EdgeInsets.all(AppSpacing.sm);

    // Build the card based on variant
    Widget card = switch (variant) {
      AppCardVariant.elevated => _buildElevatedCard(
          context,
          colorScheme,
          effectiveBorderRadius,
        ),
      AppCardVariant.filled => _buildFilledCard(
          context,
          colorScheme,
          effectiveBorderRadius,
        ),
      AppCardVariant.outlined => _buildOutlinedCard(
          context,
          colorScheme,
          effectiveBorderRadius,
        ),
    };

    // Apply margin
    card = Padding(padding: effectiveMargin, child: card);

    // Wrap with semantics if provided
    if (semanticLabel != null || _isInteractive) {
      card = Semantics(
        label: semanticLabel,
        hint: semanticHint,
        button: _isInteractive,
        selected: isSelected,
        child: card,
      );
    }

    return card;
  }

  /// Builds an elevated card variant.
  Widget _buildElevatedCard(
    BuildContext context,
    ColorScheme colorScheme,
    BorderRadius borderRadius,
  ) {
    final effectiveElevation = elevation ?? AppElevation.low;
    final effectiveBackground = backgroundColor ??
        (Theme.of(context).brightness == Brightness.light
            ? AppColors.documentCardLight
            : AppColors.documentCardDark);

    Widget content = _buildContent(colorScheme);

    return Card(
      elevation: effectiveElevation,
      color: effectiveBackground,
      surfaceTintColor: Colors.transparent,
      shape: _buildShape(borderRadius, colorScheme),
      clipBehavior: clipBehavior,
      margin: EdgeInsets.zero,
      child: _wrapInteractive(content, colorScheme),
    );
  }

  /// Builds a filled card variant.
  Widget _buildFilledCard(
    BuildContext context,
    ColorScheme colorScheme,
    BorderRadius borderRadius,
  ) {
    final effectiveBackground =
        backgroundColor ?? colorScheme.surfaceContainerHighest;

    Widget content = _buildContent(colorScheme);

    return Card(
      elevation: AppElevation.none,
      color: effectiveBackground,
      surfaceTintColor: Colors.transparent,
      shape: _buildShape(borderRadius, colorScheme),
      clipBehavior: clipBehavior,
      margin: EdgeInsets.zero,
      child: _wrapInteractive(content, colorScheme),
    );
  }

  /// Builds an outlined card variant.
  Widget _buildOutlinedCard(
    BuildContext context,
    ColorScheme colorScheme,
    BorderRadius borderRadius,
  ) {
    final effectiveBackground = backgroundColor ?? colorScheme.surface;
    final effectiveBorderColor = isSelected && showSelectedBorder
        ? colorScheme.primary
        : borderColor ?? colorScheme.outlineVariant;
    final effectiveBorderWidth = isSelected && showSelectedBorder
        ? 2.0
        : borderWidth ?? 1.0;

    Widget content = _buildContent(colorScheme);

    return Card(
      elevation: AppElevation.none,
      color: effectiveBackground,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: effectiveBorderColor,
          width: effectiveBorderWidth,
        ),
      ),
      clipBehavior: clipBehavior,
      margin: EdgeInsets.zero,
      child: _wrapInteractive(content, colorScheme),
    );
  }

  /// Builds the shape for the card.
  ShapeBorder _buildShape(BorderRadius borderRadius, ColorScheme colorScheme) {
    if (isSelected && showSelectedBorder) {
      return RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: colorScheme.primary,
          width: 2.0,
        ),
      );
    }

    return RoundedRectangleBorder(borderRadius: borderRadius);
  }

  /// Builds the card content with optional padding.
  Widget _buildContent(ColorScheme colorScheme) {
    if (padding != null) {
      return Padding(padding: padding!, child: child);
    }
    return child;
  }

  /// Wraps content with InkWell for interactive cards.
  Widget _wrapInteractive(Widget content, ColorScheme colorScheme) {
    if (!_isInteractive) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius ?? AppBorderRadius.card,
      child: content,
    );
  }
}

// ============================================================================
// App Card Header Widget
// ============================================================================

/// A standardized card header with title, subtitle, and actions.
///
/// ## Usage
/// ```dart
/// AppCard(
///   child: Column(
///     children: [
///       AppCardHeader(
///         title: 'Documents',
///         subtitle: '12 items',
///         leading: Icon(Icons.folder),
///         trailing: IconButton(
///           icon: Icon(Icons.more_vert),
///           onPressed: () {},
///         ),
///       ),
///       // ... card content
///     ],
///   ),
/// )
/// ```
class AppCardHeader extends StatelessWidget {
  /// Creates an [AppCardHeader].
  const AppCardHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
    super.key,
  });

  /// The main title text.
  final String title;

  /// Optional subtitle text.
  final String? subtitle;

  /// Widget before the title (icon, avatar, etc.).
  final Widget? leading;

  /// Widget after the title (action buttons, etc.).
  final Widget? trailing;

  /// Padding around the header.
  final EdgeInsetsGeometry? padding;

  /// Custom title text style.
  final TextStyle? titleStyle;

  /// Custom subtitle text style.
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveTitleStyle = titleStyle ??
        theme.textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        );

    final effectiveSubtitleStyle = subtitleStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );

    final effectivePadding =
        padding ?? const EdgeInsets.all(AppSpacing.cardPadding);

    return Padding(
      padding: effectivePadding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: effectiveTitleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: effectiveSubtitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// App Card Action Bar Widget
// ============================================================================

/// A standardized action bar for cards with buttons.
///
/// ## Usage
/// ```dart
/// AppCard(
///   child: Column(
///     children: [
///       // ... card content
///       AppCardActionBar(
///         actions: [
///           TextButton(
///             onPressed: () {},
///             child: Text('Cancel'),
///           ),
///           FilledButton(
///             onPressed: () {},
///             child: Text('Confirm'),
///           ),
///         ],
///       ),
///     ],
///   ),
/// )
/// ```
class AppCardActionBar extends StatelessWidget {
  /// Creates an [AppCardActionBar].
  const AppCardActionBar({
    required this.actions,
    this.alignment = MainAxisAlignment.end,
    this.padding,
    this.spacing = AppSpacing.sm,
    super.key,
  });

  /// The action widgets (typically buttons).
  final List<Widget> actions;

  /// Alignment of actions within the bar.
  final MainAxisAlignment alignment;

  /// Padding around the action bar.
  final EdgeInsetsGeometry? padding;

  /// Spacing between actions.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: AppSpacing.sm,
        );

    return Padding(
      padding: effectivePadding,
      child: Row(
        mainAxisAlignment: alignment,
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            actions[i],
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Document Card Widget
// ============================================================================

/// A specialized card for displaying document thumbnails.
///
/// Provides consistent styling for document previews with overlay information.
///
/// ## Usage
/// ```dart
/// DocumentCard(
///   thumbnail: Image.file(File(thumbnailPath)),
///   title: 'Invoice 2024',
///   subtitle: 'March 15, 2024',
///   pageCount: 3,
///   isFavorite: true,
///   onTap: () => openDocument(),
/// )
/// ```
class DocumentCard extends StatelessWidget {
  /// Creates a [DocumentCard].
  const DocumentCard({
    required this.thumbnail,
    required this.title,
    this.subtitle,
    this.pageCount,
    this.isFavorite = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.aspectRatio = 0.707, // A4 aspect ratio
    super.key,
  });

  /// The thumbnail image widget.
  final Widget thumbnail;

  /// Document title.
  final String title;

  /// Optional subtitle (date, size, etc.).
  final String? subtitle;

  /// Number of pages in the document.
  final int? pageCount;

  /// Whether the document is favorited.
  final bool isFavorite;

  /// Whether the card is selected.
  final bool isSelected;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Callback when long-pressed.
  final VoidCallback? onLongPress;

  /// Callback when favorite is toggled.
  final VoidCallback? onFavoriteToggle;

  /// Aspect ratio for the thumbnail.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      isSelected: isSelected,
      semanticLabel: _buildSemanticLabel(),
      semanticHint: onTap != null ? A11yHints.doubleTapToActivate : null,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail with overlays
          AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppBorderRadius.lg),
                  ),
                  child: thumbnail,
                ),

                // Page count badge
                if (pageCount != null && pageCount! > 1)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _buildPageCountBadge(colorScheme),
                  ),

                // Favorite button
                if (onFavoriteToggle != null)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _buildFavoriteButton(colorScheme),
                  ),

                // Selected overlay
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppBorderRadius.lg),
                        ),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: colorScheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Title and subtitle
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the semantic label for accessibility.
  String _buildSemanticLabel() {
    final parts = <String>[title];

    if (subtitle != null) {
      parts.add(subtitle!);
    }

    if (pageCount != null) {
      parts.add(A11yLabels.pageCount(pageCount!));
    }

    if (isFavorite) {
      parts.add('Favorited');
    }

    if (isSelected) {
      parts.add('Selected');
    }

    return parts.join(', ');
  }

  /// Builds the page count badge.
  Widget _buildPageCountBadge(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppBorderRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.layers,
            size: 14,
            color: colorScheme.onSurface,
          ),
          const SizedBox(width: 4),
          Text(
            '$pageCount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the favorite toggle button.
  Widget _buildFavoriteButton(ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onFavoriteToggle,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            size: 18,
            color: isFavorite ? Colors.red : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
