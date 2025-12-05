import 'package:flutter/material.dart';
import 'dart:math' as math;

class LogoSpinner extends StatefulWidget {
  final double size;
  final String assetPath; // Path to your transparent png

  const LogoSpinner({
    super.key, 
    this.size = 80.0, 
    this.assetPath = 'assets/icon/icons.png', // Default to your app icon
  });

  @override
  State<LogoSpinner> createState() => _LogoSpinnerState();
}

class _LogoSpinnerState extends State<LogoSpinner> with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. ROTATION ANIMATION (Slow & Continuous)
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // 6 seconds for one full spin (slow)
    )..repeat();

    // 2. PULSE ANIMATION (Breathing effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // 1.5 seconds in, 1.5 out
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // A. Optional: Outer Ring (Decor)
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF003366).withOpacity(0.2)),
            ),
          ),

          // B. The Logo (Animating)
          AnimatedBuilder(
            animation: Listenable.merge([_rotateController, _pulseController]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotateController.value * 2 * math.pi,
                  child: Image.asset(
                    widget.assetPath,
                    width: widget.size * 0.6, // Logo is slightly smaller than the container
                    height: widget.size * 0.6,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}