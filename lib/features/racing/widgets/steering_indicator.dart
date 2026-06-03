import 'package:flutter/material.dart';

/// Horizontal steering bar that shows current tilt.
///
/// [value] is -1 (full left) … 0 (center) … +1 (full right).
class SteeringIndicator extends StatelessWidget {
  final double value;

  const SteeringIndicator({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: LayoutBuilder(builder: (ctx, box) {
        final w      = box.maxWidth;
        final center = w / 2;
        final range  = center - 28; // padding from edges
        final x      = center + value * range; // needle X

        final needleColor = _needleColor(value);

        return Stack(
          children: [
            // Center line
            Positioned(
              left: center - 1, top: 6, bottom: 6,
              child: Container(width: 2, color: Colors.white.withOpacity(0.12)),
            ),

            // Zone markers
            _zoneBar(range, center, value),

            // L / R labels
            const Positioned(
              left: 10,
              child: _Label('L'),
            ),
            const Positioned(
              right: 10,
              child: _Label('R'),
            ),

            // Needle
            AnimatedPositioned(
              duration: const Duration(milliseconds: 40),
              curve: Curves.linear,
              left: x - 3,
              top: 4,
              bottom: 4,
              child: Container(
                width: 6,
                decoration: BoxDecoration(
                  color: needleColor,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: needleColor.withOpacity(0.85),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Filled track from center to needle
  Widget _zoneBar(double range, double center, double v) {
    final fillW = (v.abs() * range).clamp(0.0, range);
    final color = _needleColor(v).withOpacity(0.18);
    return Positioned(
      left:  v < 0 ? center - fillW : center,
      top:   0, bottom: 0,
      width: fillW,
      child: Container(color: color),
    );
  }

  Color _needleColor(double v) {
    final abs = v.abs();
    if (abs > 0.75) return const Color(0xFFE8001C); // danger red
    if (abs > 0.45) return const Color(0xFFFF9800); // caution orange
    return const Color(0xFF00C853);                  // safe green
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        color: Color(0xFF333333),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}
