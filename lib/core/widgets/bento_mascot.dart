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
  bool _isAnimationFinished = false;

  @override
  void initState() {
    super.initState();
    
    // Set duration based on variant
    final duration = widget.variant == BentoMascotVariant.settings
        ? const Duration(milliseconds: 1000)
        : const Duration(milliseconds: 480);

    _controller = AnimationController(
      duration: duration,
      vsync: this,
    );

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() {
          _isStarted = true;
          _controller.repeat();
        });
      }
    });

    if (widget.animateOnce) {
      Future.delayed(const Duration(milliseconds: 2930), () {
        if (mounted) {
          ref.read(audioServiceProvider).playPock();
          HapticFeedback.lightImpact();
          
          setState(() {
            _isAnimationFinished = true;
            _controller.stop();
          });
        }
      });
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
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        String assetPath;
        
        switch (widget.variant) {
          case BentoMascotVariant.waving:
            if (!_isStarted) {
              assetPath = 'assets/images/scanai_hello_01.png';
            } else if (_isAnimationFinished) {
              assetPath = 'assets/images/scanai_hello_03.png';
            } else {
              if (_controller.value < 0.33) {
                assetPath = 'assets/images/scanai_hello_01.png';
              } else if (_controller.value < 0.66) {
                assetPath = 'assets/images/scanai_hello_02.png';
              } else {
                assetPath = 'assets/images/scanai_hello_03.png';
              }
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
