import 'package:flutter/material.dart';

import '../../../shared/theme.dart';

/// Virtual analog thumbstick.
///
/// Reports [Offset] (x, y) in the range [-1, 1] via [onChanged].
/// Returns to center on finger-up.
class JoystickWidget extends StatefulWidget {
  final double size;
  final double deadzone;  // 0.0 – 0.3
  final String label;
  final Color  color;
  final ValueChanged<Offset> onChanged;

  const JoystickWidget({
    super.key,
    required this.size,
    required this.onChanged,
    this.deadzone = 0.08,
    this.label    = '',
    this.color    = AppTheme.accent,
  });

  @override
  State<JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _raw = Offset.zero; // [-1, 1] before deadzone

  void _update(Offset local) {
    final radius = widget.size / 2;
    final delta  = local - Offset(radius, radius);
    // Clamp thumb within the circle
    final clamped = delta.distance > radius
        ? delta / delta.distance * radius
        : delta;

    // Normalise to [-1, 1], invert Y so up is positive
    final nx =  clamped.dx / radius;
    final ny = -clamped.dy / radius;

    setState(() => _raw = Offset(nx, ny));
    widget.onChanged(_applyDeadzone(nx, ny));
  }

  void _reset() {
    setState(() => _raw = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  Offset _applyDeadzone(double x, double y) {
    final dz = widget.deadzone;
    double apply(double v) {
      if (v.abs() < dz) return 0.0;
      return (v.abs() - dz) / (1.0 - dz) * v.sign;
    }
    return Offset(apply(x), apply(y));
  }

  @override
  Widget build(BuildContext context) {
    final s      = widget.size;
    final center = s / 2;
    final thumbR = s * 0.18; // thumb radius
    final maxOff = center - thumbR - 4;

    // Thumb position in local pixels
    final tx = center + _raw.dx * maxOff;
    final ty = center - _raw.dy * maxOff;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart:  (d) => _update(d.localPosition),
      onPanUpdate: (d) => _update(d.localPosition),
      onPanEnd:    (_) => _reset(),
      onPanCancel: _reset,
      child: SizedBox(
        width: s, height: s,
        child: CustomPaint(
          painter: _JoystickPainter(
            thumbX: tx, thumbY: ty,
            size: s, color: widget.color,
          ),
          child: widget.label.isEmpty
              ? null
              : Align(
                  alignment: const Alignment(0, 0.75),
                  child: Text(widget.label, style: TextStyle(
                    fontFamily: 'monospace', fontSize: 9,
                    color: widget.color.withOpacity(0.35),
                    letterSpacing: 1.5, fontWeight: FontWeight.w700,
                  )),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter — avoids rebuilding the subtree on every drag event
// ─────────────────────────────────────────────────────────────────────────────

class _JoystickPainter extends CustomPainter {
  final double thumbX, thumbY, size;
  final Color  color;

  const _JoystickPainter({
    required this.thumbX, required this.thumbY,
    required this.size,   required this.color,
  });

  @override
  void paint(Canvas canvas, Size sz) {
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;
    final thumbR = size * 0.18;

    // ── Outer ring ────────────────────────────────────────────────────────
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = const Color(0xFF1A1A1A)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center, radius,
      Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // ── Cross-hair ────────────────────────────────────────────────────────
    final xhPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    canvas.drawLine(center - Offset(radius * 0.5, 0),
                    center + Offset(radius * 0.5, 0), xhPaint);
    canvas.drawLine(center - Offset(0, radius * 0.5),
                    center + Offset(0, radius * 0.5), xhPaint);

    // ── Dead-zone ring ────────────────────────────────────────────────────
    canvas.drawCircle(
      center, radius * 0.18,
      Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Thumb glow ─────────────────────────────────────────────────────────
    final thumbCenter = Offset(thumbX, thumbY);
    canvas.drawCircle(
      thumbCenter, thumbR + 6,
      Paint()..color = color.withOpacity(0.15)
             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // ── Thumb ─────────────────────────────────────────────────────────────
    canvas.drawCircle(
      thumbCenter, thumbR,
      Paint()..color = color.withOpacity(0.85),
    );
    canvas.drawCircle(
      thumbCenter, thumbR,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.thumbX != thumbX || old.thumbY != thumbY;
}
