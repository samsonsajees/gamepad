import 'package:flutter/material.dart';

/// A vertical drag-to-activate trigger slider.
///
/// Drag up for full depression, release to return to 0.
class TriggerSlider extends StatelessWidget {
  final double            value;    // 0.0 – 1.0
  final Color             color;
  final ValueChanged<double> onChanged;

  const TriggerSlider({
    super.key,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final h = box.maxHeight;
      final fillH = h * value;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) {
          final newVal = 1.0 - (d.localPosition.dy / h).clamp(0.0, 1.0);
          onChanged(newVal);
        },
        onVerticalDragEnd:   (_) => onChanged(0.0),
        onTapDown: (d) {
          final v = 1.0 - (d.localPosition.dy / h).clamp(0.0, 1.0);
          onChanged(v);
        },
        onTapUp:     (_) => onChanged(0.0),
        onTapCancel: ()  => onChanged(0.0),
        child: Container(
          width: 76,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Fill ──────────────────────────────────────────────────
              Positioned(
                left: 0, right: 0, bottom: 0,
                height: fillH.clamp(0.0, h),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end:   Alignment.topCenter,
                      colors: [
                        color,
                        color.withOpacity(0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Tick marks ────────────────────────────────────────────
              ...List.generate(11, (i) {
                final tickY = h / 10 * i;
                final isMajor = i % 5 == 0;
                return Positioned(
                  right: 10,
                  top: tickY.clamp(0.0, h - 1),
                  child: Container(
                    width: isMajor ? 14 : 7,
                    height: 1,
                    color: Colors.white.withOpacity(isMajor ? 0.15 : 0.07),
                  ),
                );
              }),

              // ── Hint label (only when idle) ───────────────────────────
              if (value < 0.05)
                Center(
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'DRAG',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: color.withOpacity(0.25),
                        fontSize: 9,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              // ── Glow line at fill top ─────────────────────────────────
              if (value > 0.02)
                Positioned(
                  left: 0, right: 0,
                  bottom: (fillH - 2).clamp(0.0, h),
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.9),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
