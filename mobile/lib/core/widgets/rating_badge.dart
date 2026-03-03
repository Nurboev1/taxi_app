import 'package:flutter/material.dart';

class RatingBadge extends StatelessWidget {
  const RatingBadge({
    super.key,
    required this.rating,
    this.max = 5,
    this.compact = false,
  });

  final double rating;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0, max.toDouble());
    final bg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            r.toStringAsFixed(1),
            style: TextStyle(
              fontSize: compact ? 22 : 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(width: 10),
          ...List.generate(max, (i) {
            final level = (r - i).clamp(0, 1).toDouble();
            return Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Stack(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: compact ? 24 : 30,
                    color: Colors.grey.shade400,
                  ),
                  ClipRect(
                    clipper: _PartialClip(level),
                    child: Icon(
                      Icons.star_rounded,
                      size: compact ? 24 : 30,
                      color: const Color(0xFFF4C430),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PartialClip extends CustomClipper<Rect> {
  const _PartialClip(this.fraction);
  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_PartialClip oldClipper) => oldClipper.fraction != fraction;
}
