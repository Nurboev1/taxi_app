import 'package:flutter/material.dart';

class DaytimeWaveBackground extends StatelessWidget {
  const DaytimeWaveBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF4F7FC),
            Color(0xFFEFF4FA),
            Color(0xFFF8FAFD),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _SoftCircle(
              size: 280,
              color: Color(0x1A7FA3D8),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -110,
            child: _SoftCircle(
              size: 320,
              color: Color(0x142B6CB0),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
