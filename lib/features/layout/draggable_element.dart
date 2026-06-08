import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'layout_model.dart';
import 'layout_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DraggableElement
// ─────────────────────────────────────────────────────────────────────────────
// In PLAY mode : applies the saved translate / scale / rotate transform.
// In EDIT mode : adds gesture handlers (pan = move, pinch = resize,
//                two-finger twist = rotate) and a glowing selection overlay.
//
// Positions are stored as *deltas* from the element's natural layout spot,
// so they work across different screen sizes.
// ─────────────────────────────────────────────────────────────────────────────

class DraggableElement extends ConsumerStatefulWidget {
  final String  id;
  final String  screenId; // 'racing' | 'fps'
  final String? label;    // optional name shown in edit mode
  final Widget  child;

  const DraggableElement({
    super.key,
    required this.id,
    required this.screenId,
    required this.child,
    this.label,
  });

  @override
  ConsumerState<DraggableElement> createState() => _DraggableElementState();
}

class _DraggableElementState extends ConsumerState<DraggableElement> {
  bool _gesturing = false;

  // Local state used during an active gesture (avoids a provider write per frame).
  late ElementLayout _localEl;
  double _baseScale    = 1.0;
  double _baseRotation = 0.0;

  // ── Gesture callbacks ──────────────────────────────────────────────────────

  ElementLayout _readEl() {
    final map = ref.read(layoutProvider).valueOrNull;
    return (map?[widget.screenId] ?? const ScreenLayout()).forId(widget.id);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _localEl      = _readEl();
    _baseScale    = _localEl.scale;
    _baseRotation = _localEl.rotation;
    setState(() => _gesturing = true);
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (!_gesturing) return;
    setState(() {
      _localEl = _localEl.copyWith(
        dx:       _localEl.dx + d.focalPointDelta.dx,
        dy:       _localEl.dy + d.focalPointDelta.dy,
        scale:    (_baseScale * d.scale).clamp(0.4, 2.5),
        rotation: _baseRotation + d.rotation * 180 / pi,
      );
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (!_gesturing) return;
    final snapped = _localEl.copyWith(rotation: _snapRotation(_localEl.rotation));
    setState(() => _gesturing = false);
    ref.read(layoutProvider.notifier).updateElement(widget.screenId, snapped);
  }

  /// Snap to nearest cardinal angle if within 15°.
  double _snapRotation(double deg) {
    final n = deg % 360;
    for (final snap in const [0.0, 90.0, 180.0, 270.0, 360.0]) {
      if ((n - snap).abs() < 15.0) return snap == 360.0 ? 0.0 : snap;
    }
    return deg;
  }

  // ── Transform helper ───────────────────────────────────────────────────────

  Widget _applyTransform(ElementLayout el, Widget child) =>
      Transform.translate(
        offset: Offset(el.dx, el.dy),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(el.scale)
            ..rotateZ(el.rotation * pi / 180),
          child: child,
        ),
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final editMode = ref.watch(editModeProvider(widget.screenId));

    // Resolve current element layout.
    final ElementLayout el;
    if (_gesturing) {
      el = _localEl; // smooth local update during drag
    } else {
      final layout =
          ref.watch(layoutProvider).valueOrNull?[widget.screenId] ??
              const ScreenLayout();
      el = layout.forId(widget.id);
    }

    // ── Play mode: just apply the transform ───────────────────────────────
    if (!editMode) return _applyTransform(el, widget.child);

    // ── Edit mode: gestures + selection overlay ───────────────────────────
    // IMPORTANT: GestureDetector must be INSIDE _applyTransform.
    // Transform.translate moves the visual but NOT the hit-test box of any
    // ancestor widget. By placing the GestureDetector inside the transform,
    // its hit area moves together with the painted element, so a second drag
    // always starts from wherever the element currently is.
    // (focalPointDelta is in global screen coordinates, so the drag math is
    // unaffected by the transform.)
    const borderColor   = Color(0xFF00B0FF);
    const activeBorder  = Color(0xFF00E5FF);
    final borderClr     = _gesturing ? activeBorder : borderColor;
    final borderWidth   = _gesturing ? 2.5 : 1.5;

    return _applyTransform(
      el,
      GestureDetector(
        behavior:      HitTestBehavior.opaque,
        onScaleStart:  _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd:    _onScaleEnd,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Prevent inner buttons / sliders firing in edit mode.
            AbsorbPointer(child: widget.child),

            // Glowing selection border
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderClr, width: borderWidth),
                    color: _gesturing
                        ? activeBorder.withOpacity(0.08)
                        : Colors.transparent,
                  ),
                ),
              ),
            ),

            // Element label (top-left)
            if (widget.label != null)
              Positioned(
                top: 3, left: 5,
                child: IgnorePointer(
                  child: Text(
                    widget.label!,
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 7,
                      fontWeight: FontWeight.w900, color: borderColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

            // Scale badge (bottom-right)
            Positioned(
              bottom: 3, right: 5,
              child: IgnorePointer(
                child: Text(
                  '${(el.scale * 100).round()}%',
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 7, color: borderColor,
                  ),
                ),
              ),
            ),

            // Reset-to-default button (top-right corner)
            Positioned(
              top: -10, right: -10,
              child: GestureDetector(
                onTap: () => ref
                    .read(layoutProvider.notifier)
                    .resetElement(widget.screenId, widget.id),
                child: Container(
                  width: 22, height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x66E53935), blurRadius: 6),
                    ],
                  ),
                  child: const Icon(Icons.refresh_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// EditModeBanner  — appears at the top of the screen while editing
// ─────────────────────────────────────────────────────────────────────────────

class EditModeBanner extends ConsumerWidget {
  final String screenId;
  const EditModeBanner({super.key, required this.screenId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editMode = ref.watch(editModeProvider(screenId));
    if (!editMode) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      color: const Color(0xFF00B0FF).withOpacity(0.12),
      child: const Text(
        '✏  DRAG TO MOVE   •   PINCH TO RESIZE   •   TWIST TO ROTATE   •   ⟲ TO RESET',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'monospace', fontSize: 8, letterSpacing: 1.2,
          color: Color(0xFF00B0FF), fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
