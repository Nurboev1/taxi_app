import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedBlobsBackground extends StatefulWidget {
  const AnimatedBlobsBackground({
    super.key,
    required this.child,
    required this.colors,
  });

  final Widget child;
  final List<Color> colors;

  @override
  State<AnimatedBlobsBackground> createState() =>
      _AnimatedBlobsBackgroundState();
}

class _AnimatedBlobsBackgroundState extends State<AnimatedBlobsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
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
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.colors,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -90 + (t * 20),
                right: -80 + (t * 15),
                child: _blob(220, Colors.white.withValues(alpha: 0.08)),
              ),
              Positioned(
                left: -70 + (t * 24),
                bottom: -110 + (t * 18),
                child: _blob(260, Colors.white.withValues(alpha: 0.06)),
              ),
              Positioned(
                left: 60 + (math.sin(t * math.pi * 2) * 8),
                top: 90,
                child: _blob(120, Colors.white.withValues(alpha: 0.05)),
              ),
              if (child != null) child,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}
