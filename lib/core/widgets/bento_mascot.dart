import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_service.dart';

/// Variants of the ScanAI mascot for different app sections.
enum BentoMascotVariant {
  /// Standard waving mascot (3 frames).
  waving,

  /// Settings mascot (2 frames animation).
  settings,

  /// Static security/lock mascot.
  lock,

  /// Documents mascot (4 frames animation).
  documents,

  /// Static unlock mascot (shown briefly after successful authentication).
  unlock,

  /// Folder editing mascot (static with levitation).
  folderEdit,

  /// Photo/Camera mascot (static).
  photo,
}

class BentoMascot extends ConsumerStatefulWidget {
  final double height;
  final bool animateOnce;
  final BentoMascotVariant variant;

  const BentoMascot({
    super.key,
    required this.height,
    this.animateOnce = false,
    this.variant = BentoMascotVariant.waving,
  });

  @override
  ConsumerState<BentoMascot> createState() => _BentoMascotState();
}

class _BentoMascotState extends ConsumerState<BentoMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isStarted = false;
  bool _isPaused = false;
  int _cycleCount = 0;

  /// Number of ping-pong cycles before pausing
  static const int _cyclesBeforePause = 6;

  /// Pause duration between cycle groups
  static const Duration _pauseDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();

    // Set duration based on variant
    final Duration duration;
    switch (widget.variant) {
      case BentoMascotVariant.settings:
        duration = const Duration(milliseconds: 1000);
        break;
      case BentoMascotVariant.documents:
        // 7 segments ping-pong, ~85ms per frame = 600ms
        duration = const Duration(milliseconds: 1000);
        break;
      case BentoMascotVariant.waving:
      case BentoMascotVariant.lock:
      case BentoMascotVariant.unlock:
      case BentoMascotVariant.folderEdit:
      case BentoMascotVariant.photo:
        // 5 frames ping-pong, ~80ms per frame = 400ms
        duration = const Duration(milliseconds: 400);
        break;
    }

    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    // Listen for cycle completion
    _controller.addStatusListener(_onAnimationStatus);

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isStarted = true;
        });
        _startAnimation();
      }
    });
  }

  void _onAnimationStatus(AnimationStatus status) {
    // Handle cycle counting for waving and documents variants
    final isAnimatedVariant = widget.variant == BentoMascotVariant.waving ||
        widget.variant == BentoMascotVariant.documents;

    if (status == AnimationStatus.completed && isAnimatedVariant) {
      _cycleCount++;

      if (_cycleCount >= _cyclesBeforePause) {
        // Pause after 6 cycles
        _cycleCount = 0;
        setState(() {
          _isPaused = true;
        });

        // Play sound and haptic at pause
        ref.read(audioServiceProvider).playPock();
        HapticFeedback.lightImpact();

        // Resume after 10 seconds
        Future.delayed(_pauseDuration, () {
          if (mounted && !widget.animateOnce) {
            setState(() {
              _isPaused = false;
            });
            _startAnimation();
          }
        });
      } else {
        // Continue to next cycle
        _controller.forward(from: 0);
      }
    }
  }

  void _startAnimation() {
    if (widget.variant == BentoMascotVariant.settings) {
      _controller.repeat();
    } else {
      // For waving, use forward to count cycles
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.variant == BentoMascotVariant.waving) {
      precacheImage(const AssetImage('assets/images/scanai_hello_01.png'), context);
      precacheImage(const AssetImage('assets/images/scanai_hello_02.png'), context);
      precacheImage(const AssetImage('assets/images/scanai_hello_03.png'), context);
    } else if (widget.variant == BentoMascotVariant.settings) {
      precacheImage(const AssetImage('assets/images/sacnai_settings_01.png'), context);
      precacheImage(const AssetImage('assets/images/sacnai_settings_02.png'), context);
    } else if (widget.variant == BentoMascotVariant.lock) {
      precacheImage(const AssetImage('assets/images/scani_lock.png'), context);
    } else if (widget.variant == BentoMascotVariant.documents) {
      precacheImage(const AssetImage('assets/images/scanai_documents_01.png'), context);
      precacheImage(const AssetImage('assets/images/scanai_documents_02.png'), context);
      precacheImage(const AssetImage('assets/images/scanai_documents_03.png'), context);
      precacheImage(const AssetImage('assets/images/scanai_documents_04.png'), context);
    } else if (widget.variant == BentoMascotVariant.unlock) {
      precacheImage(const AssetImage('assets/images/scanai_unlock.png'), context);
    } else if (widget.variant == BentoMascotVariant.folderEdit) {
      precacheImage(const AssetImage('assets/images/scanai_folder_edit.png'), context);
    } else if (widget.variant == BentoMascotVariant.photo) {
      precacheImage(const AssetImage('assets/images/scanai_photo.png'), context);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  /// Returns the frame for a ping-pong cycle: 03 → 02 → 01 → 02 → 03
  String _getWavingFrame() {
    final value = _controller.value;
    // 5 segments for ping-pong: 03(0-0.2), 02(0.2-0.4), 01(0.4-0.6), 02(0.6-0.8), 03(0.8-1.0)
    if (value < 0.2) {
      return 'assets/images/scanai_hello_03.png';
    } else if (value < 0.4) {
      return 'assets/images/scanai_hello_02.png';
    } else if (value < 0.6) {
      return 'assets/images/scanai_hello_01.png';
    } else if (value < 0.8) {
      return 'assets/images/scanai_hello_02.png';
    } else {
      return 'assets/images/scanai_hello_03.png';
    }
  }

  /// Returns the frame for documents ping-pong cycle: 04 → 03 → 02 → 01 → 02 → 03 → 04
  String _getDocumentsFrame() {
    final value = _controller.value;
    // 7 segments for ping-pong with 4 frames
    const segment = 1.0 / 7.0; // ~0.143
    if (value < segment) {
      return 'assets/images/scanai_documents_04.png';
    } else if (value < segment * 2) {
      return 'assets/images/scanai_documents_03.png';
    } else if (value < segment * 3) {
      return 'assets/images/scanai_documents_02.png';
    } else if (value < segment * 4) {
      return 'assets/images/scanai_documents_01.png';
    } else if (value < segment * 5) {
      return 'assets/images/scanai_documents_02.png';
    } else if (value < segment * 6) {
      return 'assets/images/scanai_documents_03.png';
    } else {
      return 'assets/images/scanai_documents_04.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        String assetPath;

        switch (widget.variant) {
          case BentoMascotVariant.waving:
            if (!_isStarted || _isPaused) {
              // At rest: show frame 03 (starting position)
              assetPath = 'assets/images/scanai_hello_03.png';
            } else {
              assetPath = _getWavingFrame();
            }
            break;
            
          case BentoMascotVariant.settings:
            // 2-frame animation
            if (_controller.value < 0.5) {
              assetPath = 'assets/images/sacnai_settings_01.png';
            } else {
              assetPath = 'assets/images/sacnai_settings_02.png';
            }
            break;
            
          case BentoMascotVariant.lock:
            assetPath = 'assets/images/scani_lock.png';
            break;

          case BentoMascotVariant.unlock:
            assetPath = 'assets/images/scanai_unlock.png';
            break;

          case BentoMascotVariant.documents:
            if (!_isStarted || _isPaused) {
              // At rest: show frame 04 (starting position)
              assetPath = 'assets/images/scanai_documents_04.png';
            } else {
              assetPath = _getDocumentsFrame();
            }
            break;

          case BentoMascotVariant.folderEdit:
            assetPath = 'assets/images/scanai_folder_edit.png';
            break;

          case BentoMascotVariant.photo:
            assetPath = 'assets/images/scanai_photo.png';
            break;
        }

        return Image.asset(
          assetPath,
          height: widget.height,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          gaplessPlayback: true,
        );
      },
    );
  }
}

/// Maintain WavingMascot as a wrapper for backward compatibility
class WavingMascot extends StatelessWidget {
  final double height;
  final bool animateOnce;

  const WavingMascot({
    super.key,
    required this.height,
    this.animateOnce = false,
  });

  @override
  Widget build(BuildContext context) {
    return BentoMascot(
      height: height,
      animateOnce: animateOnce,
      variant: BentoMascotVariant.waving,
    );
  }
}

class BentoBouncingWidget extends StatefulWidget {
  final Widget child;
  const BentoBouncingWidget({super.key, required this.child});

  @override
  State<BentoBouncingWidget> createState() => _BentoBouncingWidgetState();
}

class _BentoBouncingWidgetState extends State<BentoBouncingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

class BentoLevitationWidget extends StatefulWidget {
  final Widget child;
  const BentoLevitationWidget({super.key, required this.child});

  @override
  State<BentoLevitationWidget> createState() => _BentoLevitationWidgetState();
}

class _BentoLevitationWidgetState extends State<BentoLevitationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -10),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
