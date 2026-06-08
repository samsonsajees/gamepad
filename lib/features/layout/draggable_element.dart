import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'layout_model.dart';
import 'layout_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DraggableElement
// ─────────────────────────────────────────────────────────────────────────────
// Translation (dx/dy) is intentionally NOT applied here.
// It is applied by the parent _GameEl Positioned widget, which means the
// element's LAYOUT position (and therefore its hit-test area) always matches
// its visual position.
//
// DraggableElement only applies scale + rotation via a Transform.
//
// Interaction model (EDIT mode):
//   Unselected  — subtle outline; tap anywhere → select.
//   Selected    — bright border + two handles:
//     • Centre  ✥ (blue)   — pan to TRANSLATE (updates provider live; disk on end).
//     • Corner  ⊕ (purple) — pan to SCALE     (updates Transform live; disk on end).
//
// Coordinate note for the move handle:
//   The GestureDetector sits inside Transform(scale=s, rotateZ=r), so
//   DragUpdateDetails.delta is in the LOCAL space of that transform.
//   We apply the forward rotation×scale matrix to convert to PARENT space:
//     parent_Δ = s · Rot(r) · local_Δ
//   which is then added directly to el.dx / el.dy.
// ─────────────────────────────────────────────────────────────────────────────

class DraggableElement extends ConsumerStatefulWidget {
  final String  id;
  final String  screenId; // 'racing' | 'fps'
  final String? label;
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
  // ── Move gesture ───────────────────────────────────────────────────────────
  bool _isMoving = false;

  // ── Scale gesture ──────────────────────────────────────────────────────────
  bool           _isScaling    = false;
  double         _scaleBase    = 1.0;
  double         _scaleTotalDx = 0.0;
  ElementLayout? _liveScaleEl; // tracks live scale during the gesture

  // ── Helpers ────────────────────────────────────────────────────────────────

  ElementLayout _fromProvider() {
    final map = ref.read(layoutProvider).valueOrNull;
    return (map?[widget.screenId] ?? const ScreenLayout()).forId(widget.id);
  }

  void _select() =>
      ref.read(selectedElementProvider(widget.screenId).notifier).state =
          widget.id;

  // ── Move handlers ──────────────────────────────────────────────────────────
  // No local state for position — position is driven by the provider, which
  // the parent _GameEl Positioned widget watches synchronously.

  void _onMoveStart(DragStartDetails _) {
    setState(() { _isMoving = true; });
  }

  void _onMoveUpdate(DragUpdateDetails d) {
    if (!_isMoving) return;
    // Read latest el from provider (updateElementLive is synchronous, so this
    // always reflects the last drag update).
    final prev = _fromProvider();
    final r   = prev.rotation * pi / 180;
    final s   = prev.scale;
    final ldx = d.delta.dx;
    final ldy = d.delta.dy;
    // Convert local-space delta → parent-space (game area Stack) delta.
    final pdx = s * (ldx * cos(r) - ldy * sin(r));
    final pdy = s * (ldx * sin(r) + ldy * cos(r));
    final newEl = prev.copyWith(dx: prev.dx + pdx, dy: prev.dy + pdy);
    // Live update: in-memory only, no disk write → smooth dragging.
    ref.read(layoutProvider.notifier).updateElementLive(widget.screenId, newEl);
  }

  void _onMoveEnd(DragEndDetails _) {
    if (!_isMoving) return;
    setState(() { _isMoving = false; });
    // Persist to disk on gesture end.
    ref.read(layoutProvider.notifier)
        .updateElement(widget.screenId, _fromProvider());
  }

  // ── Scale handlers ─────────────────────────────────────────────────────────
  // Exponential: +250 px → ×2; −250 px → ×0.5.
  // Uses raw local delta intentionally — "drag right = grow" is intuitive
  // regardless of element rotation.

  void _onScaleStart(DragStartDetails _) {
    final el = _fromProvider();
    setState(() {
      _isScaling    = true;
      _scaleBase    = el.scale;
      _scaleTotalDx = 0.0;
      _liveScaleEl  = el;
    });
  }

  void _onScaleUpdate(DragUpdateDetails d) {
    if (!_isScaling || _liveScaleEl == null) return;
    _scaleTotalDx += d.delta.dx;
    final newScale =
        (_scaleBase * pow(2.0, _scaleTotalDx / 250.0)).clamp(0.4, 2.5);
    setState(() { _liveScaleEl = _liveScaleEl!.copyWith(scale: newScale); });
  }

  void _onScaleEnd(DragEndDetails _) {
    if (!_isScaling || _liveScaleEl == null) return;
    final finished = _liveScaleEl!;
    ref.read(layoutProvider.notifier).updateElement(widget.screenId, finished);
    setState(() { _isScaling = false; _liveScaleEl = finished; });
  }

  // ── Transform (scale + rotation ONLY — no translate) ──────────────────────

  Widget _applyTransform(ElementLayout el, Widget child) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.identity()
      ..scale(el.scale)
      ..rotateZ(el.rotation * pi / 180),
    child: child,
  );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final editMode   = ref.watch(editModeProvider(widget.screenId));
    final selectedId = ref.watch(selectedElementProvider(widget.screenId));
    final isSelected = selectedId == widget.id;

    // During scale: use live scale value.
    // Otherwise:   read from provider (includes live-updated dx/dy).
    final ElementLayout el;
    if (_isScaling && _liveScaleEl != null) {
      el = _liveScaleEl!;
    } else {
      final layout = ref.watch(layoutProvider).valueOrNull?[widget.screenId]
          ?? const ScreenLayout();
      el = layout.forId(widget.id);
    }

    // ── Play mode ──────────────────────────────────────────────────────────
    if (!editMode) return _applyTransform(el, widget.child);

    // ── Edit mode — UNSELECTED ─────────────────────────────────────────────
    if (!isSelected) {
      return _applyTransform(
        el,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _select,
          child: Stack(
            children: [
              AbsorbPointer(child: widget.child),
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00B0FF).withOpacity(0.30),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.label != null)
                Positioned(
                  top: 3, left: 5,
                  child: IgnorePointer(
                    child: Text(widget.label!, style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 6,
                      color: Color(0x4400B0FF), letterSpacing: 1.0,
                    )),
                  ),
                ),
              Positioned(
                bottom: 3, right: 5,
                child: IgnorePointer(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.touch_app_rounded,
                          color: Color(0x4400B0FF), size: 9),
                      SizedBox(width: 2),
                      Text('TAP', style: TextStyle(
                        fontFamily: 'monospace', fontSize: 6,
                        color: Color(0x4400B0FF), letterSpacing: 1.0,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Edit mode — SELECTED ───────────────────────────────────────────────
    const blue   = Color(0xFF00B0FF);
    const purple = Color(0xFF7C4DFF);

    return _applyTransform(
      el,
      Stack(
        clipBehavior: Clip.none,
        children: [
          // Element body — block all touch pass-through in edit mode.
          AbsorbPointer(child: widget.child),

          // Selection border (bounding box).
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: blue, width: 2.0),
                  color: blue.withOpacity(0.06),
                ),
              ),
            ),
          ),

          // Label (top-left).
          if (widget.label != null)
            Positioned(
              top: 3, left: 5,
              child: IgnorePointer(
                child: Text(widget.label!, style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 7,
                  fontWeight: FontWeight.w900, color: blue, letterSpacing: 1.2,
                )),
              ),
            ),

          // Scale readout (bottom-right).
          Positioned(
            bottom: 3, right: 5,
            child: IgnorePointer(
              child: Text('${(el.scale * 100).round()}%', style: const TextStyle(
                fontFamily: 'monospace', fontSize: 7, color: blue,
              )),
            ),
          ),

          // ── MOVE HANDLE — centre circle ──────────────────────────────────
          // Pan this to translate the element.
          // d.delta is in local (scaled+rotated) space; _onMoveUpdate corrects
          // it to parent (game area Stack) space before updating el.dx/dy.
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart:  _onMoveStart,
                onPanUpdate: _onMoveUpdate,
                onPanEnd:    _onMoveEnd,
                child: Container(
                  width: 52, height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: blue.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: blue, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: blue.withOpacity(0.40), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.open_with_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ),
          ),

          // ── SCALE HANDLE — top-right corner ─────────────────────────────
          // Being the LAST child it is hit-tested before the move handle,
          // so touches here unambiguously start the scale gesture.
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart:  _onScaleStart,
              onPanUpdate: _onScaleUpdate,
              onPanEnd:    _onScaleEnd,
              child: Container(
                width: 30, height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: purple, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x667C4DFF), blurRadius: 10)],
                ),
                child: const Icon(Icons.zoom_out_map_rounded,
                    color: Colors.white, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GameEl  — positions a DraggableElement absolutely within a Stack.
// ─────────────────────────────────────────────────────────────────────────────
// Place this as a direct child of the game-area Stack.
// [naturalLeft] and [naturalTop] define where the element lives when the user
// has not moved it (el.dx == 0, el.dy == 0).  The provider's dx/dy are pixel
// offsets added to those natural coordinates.
// ─────────────────────────────────────────────────────────────────────────────

class GameEl extends ConsumerWidget {
  final String  id;
  final String  screenId;
  final double  naturalLeft;
  final double  naturalTop;
  final String? label;
  final Widget  child;

  const GameEl({
    super.key,
    required this.id,
    required this.screenId,
    required this.naturalLeft,
    required this.naturalTop,
    required this.child,
    this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Select only this element's layout to minimise rebuilds.
    final el = ref.watch(layoutProvider.select(
      (s) => (s.valueOrNull?[screenId] ?? const ScreenLayout()).forId(id),
    ));
    return Positioned(
      left: naturalLeft + el.dx,
      top:  naturalTop  + el.dy,
      child: DraggableElement(
        id: id, screenId: screenId, label: label, child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EditModeBanner
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
      color: const Color(0xFF00B0FF).withOpacity(0.10),
      child: const Text(
        '✏  TAP TO SELECT   •   ✥ DRAG TO MOVE   •   ⊕ DRAG TO SCALE',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'monospace', fontSize: 8, letterSpacing: 1.2,
          color: Color(0xFF00B0FF), fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
