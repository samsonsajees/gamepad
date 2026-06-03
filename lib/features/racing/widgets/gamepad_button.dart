import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

/// A circular gamepad button with press animation and haptic feedback.
///
/// Calls [onPressed] on finger-down and [onReleased] on finger-up/cancel.
class GamepadButton extends StatefulWidget {
  final String      label;
  final Color       color;
  final double      size;
  final double      fontSize;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  const GamepadButton({
    super.key,
    required this.label,
    required this.color,
    required this.size,
    required this.onPressed,
    required this.onReleased,
    this.fontSize = 10,
  });

  @override
  State<GamepadButton> createState() => _GamepadButtonState();
}

class _GamepadButtonState extends State<GamepadButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.84).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down() {
    if (_pressed) return;
    _pressed = true;
    _ctrl.forward();
    widget.onPressed();
    _vibrate();
  }

  void _up() {
    if (!_pressed) return;
    _pressed = false;
    _ctrl.reverse();
    widget.onReleased();
  }

  void _vibrate() {
    Vibration.vibrate(duration: 25, amplitude: 80).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => _down(),
      onTapUp:     (_) => _up(),
      onTapCancel: ()  => _up(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: s, height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(_pressed ? 0.25 : 0.12),
            border: Border.all(
              color: widget.color.withOpacity(_pressed ? 0.9 : 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_pressed ? 0.6 : 0.2),
                blurRadius: _pressed ? 16 : 8,
                spreadRadius: _pressed ? 2 : 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              color: widget.color,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
