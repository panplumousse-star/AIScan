import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ============================================================================
// Page Transition Routes
// ============================================================================

/// Slide and fade page route transition.
///
/// Creates a smooth navigation experience with combined slide and fade effects.
/// The new page slides in from the right while fading in, following Material
/// Design 3 motion patterns.
///
/// ## Usage
/// ```dart
/// Navigator.push(
///   context,
///   SlidePageRoute(page: const DetailScreen()),
/// );
/// ```
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  /// Creates a [SlidePageRoute] with the given page.
  SlidePageRoute({
    required this.page,
    this.direction = SlideDirection.right,
    Duration? duration,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration ?? AppDuration.medium,
          reverseTransitionDuration: duration ?? AppDuration.medium,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Use curved animation for smoother feel
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            // Determine slide offset based on direction
            final Offset begin;
            switch (direction) {
              case SlideDirection.right:
                begin = const Offset(1.0, 0.0);
              case SlideDirection.left:
                begin = const Offset(-1.0, 0.0);
              case SlideDirection.up:
                begin = const Offset(0.0, 1.0);
              case SlideDirection.down:
                begin = const Offset(0.0, -1.0);
            }

            return SlideTransition(
              position: Tween<Offset>(
                begin: begin,
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(opacity: curvedAnimation, child: child),
            );
          },
        );

  /// The page widget to display.
  final Widget page;

  /// The direction from which the page slides in.
  final SlideDirection direction;
}

/// Direction for slide page transitions.
enum SlideDirection {
  /// Slide from right to left.
  right,

  /// Slide from left to right.
  left,

  /// Slide from bottom to top.
  up,

  /// Slide from top to bottom.
  down,
}

/// Fade page route transition.
///
/// Creates a gentle fade transition between pages, suitable for modal-like
/// screens or when you want a subtle navigation effect.
///
/// ## Usage
/// ```dart
/// Navigator.push(
///   context,
///   FadePageRoute(page: const SettingsScreen()),
/// );
/// ```
class FadePageRoute<T> extends PageRouteBuilder<T> {
  /// Creates a [FadePageRoute] with the given page.
  FadePageRoute({required this.page, Duration? duration})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration ?? AppDuration.medium,
          reverseTransitionDuration: duration ?? AppDuration.medium,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity:
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
        );

  /// The page widget to display.
  final Widget page;
}

/// Scale and fade page route transition.
///
/// Creates a zoom-like effect where the new page scales up from the center
/// while fading in. Suitable for modal dialogs or detail views.
///
/// ## Usage
/// ```dart
/// Navigator.push(
///   context,
///   ScalePageRoute(page: const ImagePreviewScreen()),
/// );
/// ```
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  /// Creates a [ScalePageRoute] with the given page.
  ScalePageRoute({
    required this.page,
    this.initialScale = 0.9,
    Duration? duration,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration ?? AppDuration.medium,
          reverseTransitionDuration: duration ?? AppDuration.medium,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return ScaleTransition(
              scale: Tween<double>(
                begin: initialScale,
                end: 1.0,
              ).animate(curvedAnimation),
              child: FadeTransition(opacity: curvedAnimation, child: child),
            );
          },
        );

  /// The page widget to display.
  final Widget page;

  /// Initial scale factor for the animation (default 0.9).
  final double initialScale;
}

// ============================================================================
// Animated Widgets
// ============================================================================

/// Animated fade-in widget.
///
/// Fades in its child with an optional delay and customizable duration.
/// Useful for staggered list item animations.
///
/// ## Usage
/// ```dart
/// AnimatedFadeIn(
///   delay: const Duration(milliseconds: 100),
///   child: const Text('Hello!'),
/// )
/// ```
class AnimatedFadeIn extends StatefulWidget {
  /// Creates an [AnimatedFadeIn] widget.
  const AnimatedFadeIn({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.easeOut,
    this.onComplete,
    super.key,
  });

  /// The child widget to animate.
  final Widget child;

  /// Duration of the fade animation.
  final Duration duration;

  /// Delay before starting the animation.
  final Duration delay;

  /// Animation curve.
  final Curve curve;

  /// Callback when animation completes.
  final VoidCallback? onComplete;

  @override
  State<AnimatedFadeIn> createState() => _AnimatedFadeInState();
}

class _AnimatedFadeInState extends State<AnimatedFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this);

    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward().then((_) {
          widget.onComplete?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }
}

/// Animated slide and fade-in widget.
///
/// Slides in from a direction while fading in. Perfect for list items
/// or staggered content reveal.
///
/// ## Usage
/// ```dart
/// AnimatedSlideIn(
///   delay: const Duration(milliseconds: 50),
///   direction: SlideDirection.up,
///   child: const ListTile(title: Text('Item')),
/// )
/// ```
class AnimatedSlideIn extends StatefulWidget {
  /// Creates an [AnimatedSlideIn] widget.
  const AnimatedSlideIn({
    required this.child,
    this.direction = SlideDirection.up,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.offset = 0.1,
    this.onComplete,
    super.key,
  });

  /// The child widget to animate.
  final Widget child;

  /// Direction from which to slide in.
  final SlideDirection direction;

  /// Duration of the animation.
  final Duration duration;

  /// Delay before starting the animation.
  final Duration delay;

  /// Animation curve.
  final Curve curve;

  /// Slide offset as a fraction of the widget size.
  final double offset;

  /// Callback when animation completes.
  final VoidCallback? onComplete;

  @override
  State<AnimatedSlideIn> createState() => _AnimatedSlideInState();
}

class _AnimatedSlideInState extends State<AnimatedSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this);

    final curve = CurvedAnimation(parent: _controller, curve: widget.curve);

    // Determine start offset based on direction
    final Offset startOffset;
    switch (widget.direction) {
      case SlideDirection.right:
        startOffset = Offset(widget.offset, 0);
      case SlideDirection.left:
        startOffset = Offset(-widget.offset, 0);
      case SlideDirection.up:
        startOffset = Offset(0, widget.offset);
      case SlideDirection.down:
        startOffset = Offset(0, -widget.offset);
    }

    _slideAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(curve);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward().then((_) {
          widget.onComplete?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}

/// Animated scale widget.
///
/// Scales the child with a bounce effect. Useful for emphasis or
/// appearing elements.
///
/// ## Usage
/// ```dart
/// AnimatedScaleIn(
///   child: const Icon(Icons.check_circle, size: 48),
/// )
/// ```
class AnimatedScaleIn extends StatefulWidget {
  /// Creates an [AnimatedScaleIn] widget.
  const AnimatedScaleIn({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.elasticOut,
    this.initialScale = 0.0,
    this.onComplete,
    super.key,
  });

  /// The child widget to animate.
  final Widget child;

  /// Duration of the animation.
  final Duration duration;

  /// Delay before starting the animation.
  final Duration delay;

  /// Animation curve.
  final Curve curve;

  /// Initial scale before animation starts.
  final double initialScale;

  /// Callback when animation completes.
  final VoidCallback? onComplete;

  @override
  State<AnimatedScaleIn> createState() => _AnimatedScaleInState();
}

class _AnimatedScaleInState extends State<AnimatedScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this);

    _animation = Tween<double>(
      begin: widget.initialScale,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward().then((_) {
          widget.onComplete?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

// ============================================================================
// Interactive Widgets with Micro-Interactions
// ============================================================================

/// Tappable container with scale feedback.
///
/// Provides visual feedback by scaling down slightly when pressed,
/// creating a satisfying "button press" feel.
///
/// ## Usage
/// ```dart
/// TapScaleFeedback(
///   onTap: () => print('Tapped!'),
///   child: Container(
///     color: Colors.blue,
///     child: const Text('Press me'),
///   ),
/// )
/// ```
class TapScaleFeedback extends StatefulWidget {
  /// Creates a [TapScaleFeedback] widget.
  const TapScaleFeedback({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.enabled = true,
    super.key,
  });

  /// The child widget.
  final Widget child;

  /// Called when tapped.
  final VoidCallback? onTap;

  /// Called when long-pressed.
  final VoidCallback? onLongPress;

  /// Scale factor when pressed down.
  final double scaleDown;

  /// Duration of the scale animation.
  final Duration duration;

  /// Whether the feedback is enabled.
  final bool enabled;

  @override
  State<TapScaleFeedback> createState() => _TapScaleFeedbackState();
}

class _TapScaleFeedbackState extends State<TapScaleFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enabled) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enabled) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.enabled) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

/// Animated icon button with ripple and scale effects.
///
/// Provides an enhanced icon button with scale-down feedback on press.
///
/// ## Usage
/// ```dart
/// AnimatedIconButton(
///   icon: Icons.favorite,
///   onPressed: () => print('Liked!'),
///   color: Colors.red,
/// )
/// ```
class AnimatedIconButton extends StatefulWidget {
  /// Creates an [AnimatedIconButton].
  const AnimatedIconButton({
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24.0,
    this.tooltip,
    this.enabled = true,
    super.key,
  });

  /// The icon to display.
  final IconData icon;

  /// Called when pressed.
  final VoidCallback onPressed;

  /// Icon color.
  final Color? color;

  /// Icon size.
  final double size;

  /// Tooltip text.
  final String? tooltip;

  /// Whether the button is enabled.
  final bool enabled;

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: AppDuration.short, vsync: this);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enabled) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enabled) {
      _controller.reverse();
      widget.onPressed();
    }
  }

  void _handleTapCancel() {
    if (widget.enabled) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    Widget button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size + 24,
          height: widget.size + 24,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.size,
            color:
                widget.enabled ? iconColor : iconColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// Animated toggle switch with custom styling.
///
/// An enhanced switch with smooth animations and customizable colors.
///
/// ## Usage
/// ```dart
/// AnimatedToggle(
///   value: isEnabled,
///   onChanged: (value) => setState(() => isEnabled = value),
/// )
/// ```
class AnimatedToggle extends StatelessWidget {
  /// Creates an [AnimatedToggle].
  const AnimatedToggle({
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.enabled = true,
    super.key,
  });

  /// Current value of the toggle.
  final bool value;

  /// Called when the value changes.
  final ValueChanged<bool> onChanged;

  /// Color when toggle is active.
  final Color? activeColor;

  /// Color when toggle is inactive.
  final Color? inactiveColor;

  /// Whether the toggle is enabled.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: AppDuration.standard,
        curve: Curves.easeInOut,
        width: 52,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: value
              ? (activeColor ?? colorScheme.primary)
              : (inactiveColor ?? colorScheme.surfaceContainerHighest),
        ),
        child: AnimatedAlign(
          duration: AppDuration.standard,
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? colorScheme.onPrimary : colorScheme.outline,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Loading Animations
// ============================================================================

/// Shimmer loading placeholder.
///
/// Displays a shimmering animation effect typically used while content loads.
/// Creates a professional loading skeleton UI.
///
/// ## Usage
/// ```dart
/// ShimmerLoading(
///   child: Container(
///     width: double.infinity,
///     height: 100,
///     decoration: BoxDecoration(
///       color: Colors.grey,
///       borderRadius: BorderRadius.circular(8),
///     ),
///   ),
/// )
/// ```
class ShimmerLoading extends StatefulWidget {
  /// Creates a [ShimmerLoading] widget.
  const ShimmerLoading({
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
    super.key,
  });

  /// The child to apply shimmer effect to.
  final Widget child;

  /// Base color of the shimmer.
  final Color? baseColor;

  /// Highlight color of the shimmer.
  final Color? highlightColor;

  /// Duration of one shimmer cycle.
  final Duration duration;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor =
        widget.baseColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ??
        (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [0.0, _controller.value, 1.0],
              tileMode: TileMode.clamp,
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Transform for the sliding gradient effect.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0,
      0,
    );
  }
}

/// Pulsing loading indicator.
///
/// A simple pulsing animation often used for loading states or
/// to draw attention to an element.
///
/// ## Usage
/// ```dart
/// PulsingWidget(
///   child: Container(
///     width: 50,
///     height: 50,
///     decoration: BoxDecoration(
///       color: Colors.blue,
///       shape: BoxShape.circle,
///     ),
///   ),
/// )
/// ```
class PulsingWidget extends StatefulWidget {
  /// Creates a [PulsingWidget].
  const PulsingWidget({
    required this.child,
    this.minScale = 0.9,
    this.maxScale = 1.0,
    this.duration = const Duration(milliseconds: 1000),
    super.key,
  });

  /// The child widget to pulse.
  final Widget child;

  /// Minimum scale during pulse.
  final double minScale;

  /// Maximum scale during pulse.
  final double maxScale;

  /// Duration of one pulse cycle.
  final Duration duration;

  @override
  State<PulsingWidget> createState() => _PulsingWidgetState();
}

class _PulsingWidgetState extends State<PulsingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);

    _animation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}

// ============================================================================
// List Item Animations
// ============================================================================

/// Animated list item for staggered reveal.
///
/// Wraps a list item with entrance animation, automatically calculating
/// delay based on index for staggered effects.
///
/// ## Usage
/// ```dart
/// ListView.builder(
///   itemCount: items.length,
///   itemBuilder: (context, index) {
///     return AnimatedListItem(
///       index: index,
///       child: ListTile(title: Text(items[index])),
///     );
///   },
/// )
/// ```
class AnimatedListItem extends StatelessWidget {
  /// Creates an [AnimatedListItem].
  const AnimatedListItem({
    required this.index,
    required this.child,
    this.baseDelay = const Duration(milliseconds: 50),
    this.maxDelay = const Duration(milliseconds: 500),
    this.duration = const Duration(milliseconds: 300),
    this.direction = SlideDirection.up,
    super.key,
  });

  /// Index of the item in the list.
  final int index;

  /// The child widget.
  final Widget child;

  /// Base delay between items.
  final Duration baseDelay;

  /// Maximum delay for any item.
  final Duration maxDelay;

  /// Duration of the animation.
  final Duration duration;

  /// Direction from which to slide in.
  final SlideDirection direction;

  @override
  Widget build(BuildContext context) {
    // Calculate delay with a maximum cap
    final calculatedDelay = Duration(
      milliseconds: (baseDelay.inMilliseconds * index).clamp(
        0,
        maxDelay.inMilliseconds,
      ),
    );

    return AnimatedSlideIn(
      direction: direction,
      duration: duration,
      delay: calculatedDelay,
      child: child,
    );
  }
}

// ============================================================================
// Hero Transitions
// ============================================================================

/// Custom hero animation for document cards.
///
/// Provides a smooth hero transition with material-like surface elevation.
///
/// ## Usage
/// ```dart
/// DocumentHero(
///   tag: 'document-$id',
///   child: DocumentCard(document: document),
/// )
/// ```
class DocumentHero extends StatelessWidget {
  /// Creates a [DocumentHero].
  const DocumentHero({required this.tag, required this.child, super.key});

  /// Unique hero tag.
  final Object tag;

  /// The child widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        );

        return AnimatedBuilder(
          animation: curvedAnimation,
          builder: (context, child) {
            return Material(
              elevation: 8 * (1 - curvedAnimation.value),
              borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              child: toHeroContext.widget,
            );
          },
        );
      },
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

// ============================================================================
// Animated Value Displays
// ============================================================================

/// Animated counter that animates number changes.
///
/// Smoothly animates between number values with customizable formatting.
///
/// ## Usage
/// ```dart
/// AnimatedCounter(
///   value: documentCount,
///   duration: const Duration(milliseconds: 500),
/// )
/// ```
class AnimatedCounter extends StatelessWidget {
  /// Creates an [AnimatedCounter].
  const AnimatedCounter({
    required this.value,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
    this.style,
    this.prefix = '',
    this.suffix = '',
    super.key,
  });

  /// The value to display.
  final int value;

  /// Duration of the animation.
  final Duration duration;

  /// Animation curve.
  final Curve curve;

  /// Text style.
  final TextStyle? style;

  /// Prefix text before the number.
  final String prefix;

  /// Suffix text after the number.
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        return Text('$prefix$animatedValue$suffix', style: style);
      },
    );
  }
}

/// Animated progress indicator with smooth transitions.
///
/// Animates changes in progress value with a smooth transition.
///
/// ## Usage
/// ```dart
/// AnimatedProgressBar(
///   progress: uploadProgress,
///   height: 4,
/// )
/// ```
class AnimatedProgressBar extends StatelessWidget {
  /// Creates an [AnimatedProgressBar].
  const AnimatedProgressBar({
    required this.progress,
    this.height = 4.0,
    this.backgroundColor,
    this.progressColor,
    this.duration = const Duration(milliseconds: 300),
    this.borderRadius,
    super.key,
  });

  /// Progress value between 0.0 and 1.0.
  final double progress;

  /// Height of the progress bar.
  final double height;

  /// Background color.
  final Color? backgroundColor;

  /// Progress color.
  final Color? progressColor;

  /// Duration of the animation.
  final Duration duration;

  /// Border radius of the progress bar.
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(height / 2);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surfaceContainerHighest,
        borderRadius: effectiveBorderRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeInOut,
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  color: progressColor ?? colorScheme.primary,
                  borderRadius: effectiveBorderRadius,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// Utility Extensions
// ============================================================================

/// Extension for creating animated navigation.
extension AnimatedNavigationExtension on NavigatorState {
  /// Push a page with a slide transition.
  Future<T?> pushSlide<T extends Object?>(
    Widget page, {
    SlideDirection direction = SlideDirection.right,
    Duration? duration,
  }) {
    return push<T>(
      SlidePageRoute<T>(page: page, direction: direction, duration: duration),
    );
  }

  /// Push a page with a fade transition.
  Future<T?> pushFade<T extends Object?>(Widget page, {Duration? duration}) {
    return push<T>(FadePageRoute<T>(page: page, duration: duration));
  }

  /// Push a page with a scale transition.
  Future<T?> pushScale<T extends Object?>(
    Widget page, {
    double initialScale = 0.9,
    Duration? duration,
  }) {
    return push<T>(
      ScalePageRoute<T>(
        page: page,
        initialScale: initialScale,
        duration: duration,
      ),
    );
  }
}

/// Extension on BuildContext for animated navigation.
extension AnimatedNavigationContextExtension on BuildContext {
  /// Push a page with a slide transition.
  Future<T?> pushSlide<T extends Object?>(
    Widget page, {
    SlideDirection direction = SlideDirection.right,
    Duration? duration,
  }) {
    return Navigator.of(
      this,
    ).pushSlide<T>(page, direction: direction, duration: duration);
  }

  /// Push a page with a fade transition.
  Future<T?> pushFade<T extends Object?>(Widget page, {Duration? duration}) {
    return Navigator.of(this).pushFade<T>(page, duration: duration);
  }

  /// Push a page with a scale transition.
  Future<T?> pushScale<T extends Object?>(
    Widget page, {
    double initialScale = 0.9,
    Duration? duration,
  }) {
    return Navigator.of(
      this,
    ).pushScale<T>(page, initialScale: initialScale, duration: duration);
  }
}
