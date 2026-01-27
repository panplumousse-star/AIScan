import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'bento_card.dart';
import 'bento_mascot.dart';

/// A Bento-style loading view with mascot and progress indicator.
///
/// Features:
/// - Animated levitating mascot
/// - Circular progress indicator
/// - Optional loading message
/// - Consistent styling across the app
class BentoLoadingView extends StatelessWidget {
  const BentoLoadingView({
    super.key,
    this.message,
    this.mascotHeight = 120,
    this.mascotVariant = BentoMascotVariant.waving,
  });

  final String? message;
  final double mascotHeight;
  final BentoMascotVariant mascotVariant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayMessage = message ?? l10n?.pleaseWait ?? 'Please wait...';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BentoLevitationWidget(
            child: BentoMascot(
              height: mascotHeight,
              variant: mascotVariant,
            ),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayMessage,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A Bento-style error view with mascot and retry button.
///
/// Features:
/// - Friendly error message with mascot
/// - Retry button with consistent styling
/// - Wrapped in a BentoCard for visual consistency
/// - Customizable error message
class BentoErrorView extends StatelessWidget {
  const BentoErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.title,
    this.retryLabel,
    this.mascotHeight = 80,
    this.mascotVariant = BentoMascotVariant.waving,
  });

  final String message;
  final VoidCallback onRetry;
  final String? title;
  final String? retryLabel;
  final double mascotHeight;
  final BentoMascotVariant mascotVariant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final displayTitle =
        title ?? l10n?.somethingWentWrong ?? 'Oops! Something went wrong';
    final displayRetryLabel = retryLabel ?? l10n?.retry ?? 'Retry';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: BentoCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BentoMascot(
                height: mascotHeight,
                variant: mascotVariant,
              ),
              const SizedBox(height: 24),
              Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  displayRetryLabel,
                  style: TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Bento-style empty state view with mascot and action button.
///
/// Features:
/// - Friendly empty state message with mascot or icon
/// - Optional action button
/// - Consistent styling across the app
/// - Customizable icon, title, and description
class BentoEmptyView extends StatelessWidget {
  const BentoEmptyView({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.mascotVariant,
    this.mascotHeight = 80,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData? icon;
  final BentoMascotVariant? mascotVariant;
  final double mascotHeight;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mascotVariant != null)
              BentoMascot(
                height: mascotHeight,
                variant: mascotVariant!,
              )
            else if (icon != null)
              Icon(
                icon,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontFamily: 'Outfit',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(200, 48),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A Bento-style no results view for search and filter states.
///
/// Features:
/// - Friendly no results message with mascot or icon
/// - Optimized for search and filter result scenarios
/// - Optional action button (e.g., clear filters)
/// - Consistent styling across the app
/// - Customizable icon, title, and description
class BentoNoResultsView extends StatelessWidget {
  const BentoNoResultsView({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.mascotVariant,
    this.mascotHeight = 80,
    this.actionLabel,
    this.onAction,
  });

  final String? title;
  final String? description;
  final IconData? icon;
  final BentoMascotVariant? mascotVariant;
  final double mascotHeight;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayTitle = title ?? 'No results found';
    final displayDescription =
        description ?? 'Try adjusting your search or filters';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mascotVariant != null)
              BentoMascot(
                height: mascotHeight,
                variant: mascotVariant!,
              )
            else
              Icon(
                icon ?? Icons.search_off_rounded,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            const SizedBox(height: 24),
            Text(
              displayTitle,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              displayDescription,
              style: TextStyle(
                fontFamily: 'Outfit',
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(200, 48),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                      fontFamily: 'Outfit', fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
