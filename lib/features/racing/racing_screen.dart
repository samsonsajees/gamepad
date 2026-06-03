import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/packet_encoder.dart';
import '../../core/tcp_client.dart';
import '../../shared/theme.dart';
import '../connection/connection_provider.dart';
import 'packet_sender.dart';
import 'racing_providers.dart';
import 'widgets/gamepad_button.dart';
import 'widgets/steering_indicator.dart';
import 'widgets/trigger_slider.dart';

class RacingScreen extends ConsumerStatefulWidget {
  const RacingScreen({super.key});

  @override
  ConsumerState<RacingScreen> createState() => _RacingScreenState();
}

class _RacingScreenState extends ConsumerState<RacingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(packetSenderProvider).start();
    });
  }

  @override
  void dispose() {
    ref.read(packetSenderProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(controllerStateProvider);
    final connStatus = ref.watch(connectionStatusStreamProvider).valueOrNull
        ?? ConnectionStatus.disconnected;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Subtle grid background
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          SafeArea(
            child: Column(
              children: [
                // ── Header bar ──────────────────────────────────────────
                _Header(status: connStatus, ctrl: ctrl),
                const SizedBox(height: 6),

                // ── Steering indicator ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: SteeringIndicator(value: ctrl.steeringAngle),
                ),
                const SizedBox(height: 8),

                // ── Main controls ───────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // LEFT — Brake
                        _TriggerColumn(
                          label: 'BRAKE',
                          pct: ctrl.leftTrigger,
                          color: const Color(0xFFE8001C),
                          onChanged: (v) => ref
                              .read(controllerStateProvider.notifier)
                              .setLeftTrigger(v),
                        ),

                        // CENTER — Action buttons
                        Expanded(child: _CenterPanel(ctrl: ctrl)),

                        // RIGHT — Throttle
                        _TriggerColumn(
                          label: 'THROTTLE',
                          pct: ctrl.rightTrigger,
                          color: const Color(0xFF00C853),
                          onChanged: (v) => ref
                              .read(controllerStateProvider.notifier)
                              .setRightTrigger(v),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final ConnectionStatus status;
  final ControllerState  ctrl;

  const _Header({required this.status, required this.ctrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deg     = (ctrl.steeringAngle * 100).round();
    final degStr  = deg == 0
        ? 'CENTER'
        : '${deg.abs()}°  ${deg < 0 ? "LEFT" : "RIGHT"}';
    final dotClr  = switch (status) {
      ConnectionStatus.connected    => AppTheme.green,
      ConnectionStatus.connecting   => AppTheme.orange,
      _                             => AppTheme.textDim,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Connection dot
          _Dot(color: dotClr),
          const SizedBox(width: 10),
          const Text(
            'RACING MODE',
            style: TextStyle(
              fontFamily: 'monospace',
              color: AppTheme.textPri,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),

          // Steering readout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '⟲  $degStr',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Disconnect
          GestureDetector(
            onTap: () async {
              ref.read(packetSenderProvider).stop();
              await ref.read(connectionNotifierProvider.notifier).disconnect();
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.close_rounded,
                  color: AppTheme.textSec, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trigger column (left or right)
// ─────────────────────────────────────────────────────────────────────────────

class _TriggerColumn extends StatelessWidget {
  final String  label;
  final double  pct;
  final Color   color;
  final ValueChanged<double> onChanged;

  const _TriggerColumn({
    required this.label,
    required this.pct,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: color.withOpacity(0.75),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TriggerSlider(
              value: pct,
              color: color,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(pct * 100).round()}%',
            style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Center panel – handbrake, start, back, D-pad
// ─────────────────────────────────────────────────────────────────────────────

class _CenterPanel extends ConsumerWidget {
  final ControllerState ctrl;
  const _CenterPanel({required this.ctrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(controllerStateProvider.notifier);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // ── Handbrake ──────────────────────────────────────────────
        GamepadButton(
          label: 'HAND\nBRAKE',
          color: const Color(0xFFFF9800),
          size: 80,
          fontSize: 10,
          onPressed:  () => n.pressButton(PacketEncoder.btnA),
          onReleased: () => n.releaseButton(PacketEncoder.btnA),
        ),

        // ── Start / Back ───────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GamepadButton(
              label: 'MAP',
              color: AppTheme.textSec,
              size: 46,
              fontSize: 9,
              onPressed:  () => n.pressButton(PacketEncoder.btnBack),
              onReleased: () => n.releaseButton(PacketEncoder.btnBack),
            ),
            const SizedBox(width: 14),
            GamepadButton(
              label: 'BACK',
              color: AppTheme.textSec,
              size: 46,
              fontSize: 9,
              onPressed:  () => n.pressButton(PacketEncoder.btnStart),
              onReleased: () => n.releaseButton(PacketEncoder.btnStart),
            ),
          ],
        ),

        // ── D-Pad (for menus) ─────────────────────────────────────
        _DPad(n: n),
      ],
    );
  }
}

class _DPad extends StatelessWidget {
  final ControllerStateNotifier n;
  const _DPad({required this.n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _dBtn('▲', PacketEncoder.btnDpadUp),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dBtn('◀', PacketEncoder.btnDpadLeft),
            const SizedBox(width: 28),
            _dBtn('▶', PacketEncoder.btnDpadRight),
          ],
        ),
        _dBtn('▼', PacketEncoder.btnDpadDown),
      ],
    );
  }

  Widget _dBtn(String icon, int mask) => GestureDetector(
    onTapDown:   (_) => n.pressButton(mask),
    onTapUp:     (_) => n.releaseButton(mask),
    onTapCancel: ()  => n.releaseButton(mask),
    child: Container(
      margin: const EdgeInsets.all(2),
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.border),
      ),
      alignment: Alignment.center,
      child: Text(
        icon,
        style: const TextStyle(
          color: AppTheme.textSec,
          fontSize: 12,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 9, height: 9,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.6),
          blurRadius: 6,
          spreadRadius: 1,
        ),
      ],
    ),
  );
}

/// Very faint grid drawn once (shouldRepaint = false).
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
