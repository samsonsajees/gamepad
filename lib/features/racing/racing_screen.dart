import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/packet_encoder.dart';
import '../../core/tcp_client.dart';
import '../../shared/theme.dart';
import '../connection/connection_provider.dart';
import '../fps/fps_screen.dart';
import '../settings/settings_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(packetSenderProvider).start(),
    );
  }

  @override
  void dispose() {
    ref.read(packetSenderProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl   = ref.watch(controllerStateProvider);
    final status = ref.watch(connectionStatusStreamProvider).valueOrNull
        ?? ConnectionStatus.disconnected;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          SafeArea(
            child: Column(
              children: [
                _Header(status: status, ctrl: ctrl),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: SteeringIndicator(value: ctrl.steeringAngle),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TriggerCol(
                          label: 'BRAKE',
                          pct:   ctrl.leftTrigger,
                          color: const Color(0xFFE8001C),
                          onChanged: (v) => ref
                              .read(controllerStateProvider.notifier)
                              .setLeftTrigger(v),
                        ),
                        Expanded(child: _CenterPanel(ctrl: ctrl)),
                        _TriggerCol(
                          label: 'THROTTLE',
                          pct:   ctrl.rightTrigger,
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
    final deg    = (ctrl.steeringAngle * 100).round();
    final degStr = deg == 0
        ? 'CENTER'
        : '${deg.abs()}°  ${deg < 0 ? "LEFT" : "RIGHT"}';
    final dotClr = switch (status) {
      ConnectionStatus.connected    => AppTheme.green,
      ConnectionStatus.reconnecting => AppTheme.orange,
      ConnectionStatus.connecting   => AppTheme.orange,
      _                             => AppTheme.textDim,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _Dot(color: dotClr),
          const SizedBox(width: 8),
          const Text('RACING', style: TextStyle(
            fontFamily: 'monospace', color: AppTheme.textPri,
            fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3,
          )),
          const SizedBox(width: 10),
          // Steering readout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('⟲  $degStr', style: const TextStyle(
              fontFamily: 'monospace', color: AppTheme.accent,
              fontSize: 10, fontWeight: FontWeight.w700,
            )),
          ),
          const Spacer(),
          // Switch to FPS layout
          _IconBtn(
            label: 'FPS',
            onTap: () {
              ref.read(packetSenderProvider).stop();
              Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const FpsScreen()));
            },
          ),
          const SizedBox(width: 6),
          // Settings
          _IconBtn(
            icon: Icons.settings_rounded,
            onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 6),
          // Disconnect
          _IconBtn(
            icon: Icons.close_rounded,
            onTap: () async {
              ref.read(packetSenderProvider).stop();
              await ref.read(connectionNotifierProvider.notifier).disconnect();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trigger column
// ─────────────────────────────────────────────────────────────────────────────

class _TriggerCol extends StatelessWidget {
  final String label;
  final double pct;
  final Color  color;
  final ValueChanged<double> onChanged;
  const _TriggerCol({
    required this.label, required this.pct,
    required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Text(label, style: TextStyle(
            fontFamily: 'monospace', color: color.withOpacity(0.75),
            fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2,
          )),
          const SizedBox(height: 6),
          Expanded(child: TriggerSlider(value: pct, color: color, onChanged: onChanged)),
          const SizedBox(height: 6),
          Text('${(pct * 100).round()}%', style: TextStyle(
            fontFamily: 'monospace', color: color,
            fontSize: 18, fontWeight: FontWeight.w900,
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Center panel
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
        GamepadButton(
          label: 'HAND\nBRAKE', color: const Color(0xFFFF9800),
          size: 80, fontSize: 10,
          onPressed:  () => n.pressButton(PacketEncoder.btnA),
          onReleased: () => n.releaseButton(PacketEncoder.btnA),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GamepadButton(
            label: 'BACK', color: AppTheme.textSec, size: 46, fontSize: 9,
            onPressed:  () => n.pressButton(PacketEncoder.btnBack),
            onReleased: () => n.releaseButton(PacketEncoder.btnBack),
          ),
          const SizedBox(width: 14),
          GamepadButton(
            label: 'START', color: AppTheme.textSec, size: 46, fontSize: 9,
            onPressed:  () => n.pressButton(PacketEncoder.btnStart),
            onReleased: () => n.releaseButton(PacketEncoder.btnStart),
          ),
        ]),
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
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _dBtn('▲', PacketEncoder.btnDpadUp),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _dBtn('◀', PacketEncoder.btnDpadLeft),
        const SizedBox(width: 28),
        _dBtn('▶', PacketEncoder.btnDpadRight),
      ]),
      _dBtn('▼', PacketEncoder.btnDpadDown),
    ]);
  }

  Widget _dBtn(String icon, int mask) => GestureDetector(
    onTapDown:   (_) => n.pressButton(mask),
    onTapUp:     (_) => n.releaseButton(mask),
    onTapCancel: ()  => n.releaseButton(mask),
    child: Container(
      margin: const EdgeInsets.all(2), width: 32, height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(icon, style: const TextStyle(
          color: AppTheme.textSec, fontSize: 12)),
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
      color: color, shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)],
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData?  icon;
  final String?    label;
  final VoidCallback onTap;
  const _IconBtn({this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: icon != null
          ? Icon(icon, color: AppTheme.textSec, size: 15)
          : Center(child: Text(label!, style: const TextStyle(
              fontFamily: 'monospace', color: AppTheme.textSec,
              fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5,
            ))),
    ),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.025)..strokeWidth = 1;
    for (double x = 0; x < size.width;  x += 44)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 44)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override
  bool shouldRepaint(_) => false;
}
