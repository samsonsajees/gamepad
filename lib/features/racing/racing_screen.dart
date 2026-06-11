import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/packet_encoder.dart';
import '../../core/tcp_client.dart';
import '../../shared/theme.dart';
import '../connection/connection_provider.dart';
import '../connection/connection_screen.dart';
import '../fps/fps_screen.dart';
import '../layout/draggable_element.dart';
import '../layout/layout_provider.dart';
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
  ControllerStateNotifier? _notifier;
  PacketSender? _sender;

  @override
  void initState() {
    super.initState();
    // Lock to landscape for the gamepad layout
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifier = ref.read(controllerStateProvider.notifier);
      _sender = ref.read(packetSenderProvider);
      _notifier!.startSensors(); // always restart — notifier persists across navigations
      _sender!.start();
    });
  }

  @override
  void dispose() {
    _notifier?.stopSensors();
    // NOTE: Do NOT stop the shared PacketSender here.
    // dispose() runs AFTER the next screen's initState, so calling
    // _sender?.stop() would kill the FPS sender that was just started.
    // Button handlers already stop it explicitly before navigating.
    // NOTE: Do NOT restore portrait here — dispose() fires AFTER the next
    // screen's initState, so it would undo the landscape lock set by FpsScreen.
    // Portrait is restored explicitly in the disconnect handler instead.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl   = ref.watch(controllerStateProvider);
    final status = ref.watch(connectionStatusStreamProvider).valueOrNull
        ?? ConnectionStatus.disconnected;
    final n = ref.read(controllerStateProvider.notifier);

    ref.listen(connectionStatusStreamProvider, (prev, next) async {
      final stat = next.valueOrNull;
      // If server drops or connection fails, auto-navigate to connection screen
      if (stat == ConnectionStatus.disconnected || stat == ConnectionStatus.error) {
        ref.read(controllerStateProvider.notifier).stopSensors();
        ref.read(packetSenderProvider).stop();
        ref.read(connectionNotifierProvider.notifier).disconnect();

        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);

        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ConnectionScreen()),
            (route) => false,
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          SafeArea(
            child: Column(
              children: [
                _Header(status: status, ctrl: ctrl),
                const EditModeBanner(screenId: 'racing'),
                // ── Game area — full Stack so every element's layout position
                // matches its visual position (fixes hit-testing after move). ──
                Expanded(
                  child: LayoutBuilder(builder: (_, bc) {
                    final w = bc.maxWidth;
                    final h = bc.maxHeight;
                    return Stack(
                      children: [
                        // Steering — top centre
                        GameEl(
                          id: 'steering', screenId: 'racing',
                          label: 'STEERING',
                          naturalLeft: w * 0.12, naturalTop: 8,
                          child: SizedBox(
                            width: w * 0.76,
                            child: SteeringIndicator(
                                value: ctrl.steeringAngle),
                          ),
                        ),
                        // Brake — left
                        GameEl(
                          id: 'brake', screenId: 'racing',
                          label: 'BRAKE',
                          naturalLeft: 12, naturalTop: 58,
                          child: SizedBox(
                            height: h - 78,
                            child: _TriggerCol(
                              label: 'BRAKE',
                              pct:   ctrl.leftTrigger,
                              color: const Color(0xFFE8001C),
                              onChanged: n.setLeftTrigger,
                            ),
                          ),
                        ),
                        // Throttle — right
                        GameEl(
                          id: 'throttle', screenId: 'racing',
                          label: 'THROTTLE',
                          naturalLeft: w - 96, naturalTop: 58,
                          child: SizedBox(
                            height: h - 78,
                            child: _TriggerCol(
                              label: 'THROTTLE',
                              pct:   ctrl.rightTrigger,
                              color: const Color(0xFF00C853),
                              onChanged: n.setRightTrigger,
                            ),
                          ),
                        ),
                        // Handbrake — centre top
                        GameEl(
                          id: 'handbrake', screenId: 'racing',
                          label: 'HANDBRAKE',
                          naturalLeft: (w - 80) / 2,
                          naturalTop: h * 0.12,
                          child: GamepadButton(
                            label: 'HAND\nBRAKE',
                            color: const Color(0xFFFF9800),
                            size: 80, fontSize: 10,
                            onPressed:  () => n.pressButton(
                                PacketEncoder.btnA),
                            onReleased: () => n.releaseButton(
                                PacketEncoder.btnA),
                          ),
                        ),
                        // Back / Start — centre
                        GameEl(
                          id: 'back_start', screenId: 'racing',
                          label: 'BACK / START',
                          naturalLeft: (w - 106) / 2,
                          naturalTop: h * 0.48,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GamepadButton(
                                label: 'BACK',
                                color: AppTheme.textSec,
                                size: 46, fontSize: 9,
                                onPressed:  () => n.pressButton(
                                    PacketEncoder.btnBack),
                                onReleased: () => n.releaseButton(
                                    PacketEncoder.btnBack),
                              ),
                              const SizedBox(width: 14),
                              GamepadButton(
                                label: 'START',
                                color: AppTheme.textSec,
                                size: 46, fontSize: 9,
                                onPressed:  () => n.pressButton(
                                    PacketEncoder.btnStart),
                                onReleased: () => n.releaseButton(
                                    PacketEncoder.btnStart),
                              ),
                            ],
                          ),
                        ),
                        // D-Pad — centre bottom
                        GameEl(
                          id: 'dpad', screenId: 'racing',
                          label: 'D-PAD',
                          naturalLeft: (w - 100) / 2,
                          naturalTop: h * 0.68,
                          child: _DPad(n: n),
                        ),
                      ],
                    );
                  }),
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
    final editMode = ref.watch(editModeProvider('racing'));

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
          // Edit / Done toggle
          _IconBtn(
            label: editMode ? 'DONE' : 'EDIT',
            accent: editMode ? AppTheme.green : null,
            onTap: () {
              if (editMode) {
                // Exiting edit mode — clear any selection so the next entry
                // starts with no element pre-selected.
                ref.read(selectedElementProvider('racing').notifier).state = null;
              }
              ref.read(editModeProvider('racing').notifier).state = !editMode;
            },
          ),
          const SizedBox(width: 6),
          // Switch to FPS layout (hidden in edit mode to prevent accidental nav)
          if (!editMode) ...[  
            _IconBtn(
              label: 'FPS',
              onTap: () {
                ref.read(packetSenderProvider).stop();
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const FpsScreen()));
              },
            ),
            const SizedBox(width: 6),
          ],
          // Settings
          _IconBtn(
            icon: Icons.settings_rounded,
            onTap: () async {
              await Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()));
              await SystemChrome.setPreferredOrientations([
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]);
            },
          ),
          const SizedBox(width: 6),
          // Disconnect (hidden in edit mode)
          if (!editMode)
            _IconBtn(
              icon: Icons.close_rounded,
              onTap: () async {
                ref.read(controllerStateProvider.notifier).stopSensors();
                ref.read(packetSenderProvider).stop();
                await ref.read(connectionNotifierProvider.notifier).disconnect();
                await SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ConnectionScreen()),
                  );
                }
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

// _CenterPanel removed — its elements are inlined in the Stack game area.

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
  final IconData?    icon;
  final String?      label;
  final VoidCallback onTap;
  final Color?       accent; // optional tint for active state
  const _IconBtn({this.icon, this.label, required this.onTap, this.accent});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: accent != null ? accent!.withOpacity(0.15) : AppTheme.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent ?? AppTheme.border),
      ),
      child: icon != null
          ? Icon(icon, color: accent ?? AppTheme.textSec, size: 15)
          : Center(child: Text(label!, style: TextStyle(
              fontFamily: 'monospace', color: accent ?? AppTheme.textSec,
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
