import 'package:flutter/material.dart';

class DaytimeWaveBackground extends StatelessWidget {
  const DaytimeWaveBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/day_wave_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

