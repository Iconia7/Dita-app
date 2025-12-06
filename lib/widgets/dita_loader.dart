import 'dart:math' as math;
import 'package:flutter/material.dart';

class DaystarSpinner extends StatefulWidget {
  final double size;
  final Color color;

  const DaystarSpinner({
    super.key,
    this.size = 100.0,
    this.color = const Color(0xFF004C99), // Deep Blue (Daystar Brand)
  });

  @override
  State<DaystarSpinner> createState() => _DaystarSpinnerState();
}

class _DaystarSpinnerState extends State<DaystarSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Animations
  late Animation<double> _tipDistance;
  late Animation<double> _tipOpacity;
  late Animation<double> _coreRotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), // 2.5s Loop
    );

    // 1. Tips Ease Outward (0% -> 40% of time)
    _tipDistance = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 15.0)
            .chain(CurveTween(curve: Curves.elasticOut)), // Elastic pop
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 15.0, end: 15.0), // Hold
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 15.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)), // Smooth return
        weight: 40,
      ),
    ]).animate(_controller);

    // 2. Tips Fade Slightly (0% -> 40% -> 100%)
    _tipOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.6),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 1.0),
        weight: 60,
      ),
    ]).animate(_controller);

    // 3. Core Rotation (Full 360 spin during the hold phase)
    _coreRotation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOutBack),
      ),
    );

    _controller.repeat();
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
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _StarPainter(
            color: widget.color,
            tipDistance: _tipDistance.value,
            tipOpacity: _tipOpacity.value,
            coreRotation: _coreRotation.value,
          ),
        );
      },
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  final double tipDistance;
  final double tipOpacity;
  final double coreRotation;

  _StarPainter({
    required this.color,
    required this.tipDistance,
    required this.tipOpacity,
    required this.coreRotation,
  });

@override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    
    final Paint corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Paint tipPaint = Paint()
      ..color = color.withOpacity(tipOpacity)
      ..style = PaintingStyle.fill;

    // --- 1. DRAW ROTATING CORE (Much Bigger) ---
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(coreRotation); 
    
    Path corePath = Path();
    // INCREASED SIZE: from 0.20 to 0.35
    double coreSize = radius * 0.35; 
    double innerCore = coreSize * 0.4; // Maintain cross proportions
    
    // Draw Daystar Cross (Long Bottom)
    corePath.moveTo(0, -coreSize);          // Top
    corePath.lineTo(innerCore, -innerCore); 
    corePath.lineTo(coreSize, 0);           // Right
    corePath.lineTo(innerCore, innerCore);  
    corePath.lineTo(0, coreSize * 2.5);     // Bottom (Long Tail)
    corePath.lineTo(-innerCore, innerCore); 
    corePath.lineTo(-coreSize, 0);          // Left
    corePath.lineTo(-innerCore, -innerCore);
    corePath.close();
    
    canvas.drawPath(corePath, corePaint);
    canvas.restore();

    // --- 2. DRAW FLOATING TIPS (Smaller & Diagonal) ---
    
    // DECREASED SIZE: Tips are now smaller accents
    double baseTipLength = radius * 0.25; 
    double tipWidth = radius * 0.10; 
    
    // Pushed start offset out so they clear the larger core
    double startOffset = radius * 0.40 + tipDistance; 

    void drawTip(double angle) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      
      Path tipPath = Path();
      // Triangle pointing outward
      tipPath.moveTo(0, -startOffset - baseTipLength); // Sharp Tip
      tipPath.lineTo(tipWidth / 2, -startOffset);      // Base Right
      tipPath.lineTo(-tipWidth / 2, -startOffset);     // Base Left
      tipPath.close();

      canvas.drawPath(tipPath, tipPaint);
      canvas.restore();
    }

    // Diagonal positions (Between the cross arms)
    drawTip(math.pi / 4);      // North-East
    drawTip(3 * math.pi / 4);  // South-East
    drawTip(5 * math.pi / 4);  // South-West
    drawTip(7 * math.pi / 4);  // North-West
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => true;
}