import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/packet_encoder.dart';
import '../../core/tcp_client.dart';
import '../../shared/theme.dart';
import '../connection/connection_provider.dart';
import '../connection/connection_screen.dart';
import '../layout/draggable_element.dart';
import '../layout/layout_provider.dart';
import '../racing/packet_sender.dart';
import '../racing/racing_screen.dart';
import '../settings/settings_provider.dart';
import '../settings/settings_screen.dart';
import 'fps_providers.dart';
import 'widgets/joystick_widget.dart';

class FpsScreen extends ConsumerStatefulWidget {
  const FpsScreen({super.key});
  @override
  ConsumerState<FpsScreen> createState() => _FpsScreenState();
}

class _FpsScreenState extends ConsumerState<FpsScreen> {
  FpsControllerNotifier? _notifier;
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
      _notifier = ref.read(fpsControllerProvider.notifier);
      _sender = ref.read(packetSenderProvider);
      _notifier!.startSensors(); // always restart — notifier persists across navigations
      _sender!.startFps();
    });
  }

  @override
  void dispose() {
    _notifier?.stopSensors();
    // NOTE: Do NOT stop the shared PacketSender here.
    // dispose() runs AFTER the next screen's initState, so calling
    // _sender?.stop() would kill the sender that was just restarted.
    // Button handlers already stop it explicitly before navigating.
    // NOTE: Do NOT restore portrait here — dispose() fires AFTER the next
    // screen's initState, so it would undo the landscape lock set by RacingScreen.
    // Portrait is restored explicitly in the disconnect handler instead.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl    = ref.watch(fpsControllerProvider);
    final status  = ref.watch(connectionStatusStreamProvider).valueOrNull
        ?? ConnectionStatus.disconnected;
    final settings = ref.watch(settingsProvider).valueOrNull
        ?? const GameSettings();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          SafeArea(
            child: Column(
              children: [
                _FpsHeader(status: status, gyroOn: settings.gyroEnabled),
                // Hint banner — visible only in edit mode
                const EditModeBanner(screenId: 'fps'),
                // ── Diagnostic: remove after debugging ──
                Builder(builder: (_) {
                  final s = ref.read(packetSenderProvider);
                  return Text(
                    'SENDER: ${s.isRunning ? "RUN" : "STOP"} '
                    'fps=${s.isFpsMode} sent=${s.sendCount}',
                    style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 9,
                      color: Colors.yellow,
                    ),
                  );
                }),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: _buildMainLayout(ctrl, settings),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLayout(FpsControllerState ctrl, GameSettings settings) {
    final n = ref.read(fpsControllerProvider.notifier);

    return LayoutBuilder(builder: (_, bc) {
      final w = bc.maxWidth;
      final h = bc.maxHeight;
      return Stack(
        children: [
          // ── LB / LT — top-left ─────────────────────────────────────────────
          GameEl(
            id: 'lb_lt', screenId: 'fps', label: 'LB / LT',
            naturalLeft: 0, naturalTop: 0,
            child: SizedBox(
              width: 130,
              child: Row(children: [
                _ShoulderBtn(
                  label: 'LB',
                  onDown: () => n.pressButton(PacketEncoder.btnLB),
                  onUp:   () => n.releaseButton(PacketEncoder.btnLB),
                ),
                const SizedBox(width: 6),
                Expanded(child: _TriggerBar(
                  label: 'LT',
                  value: ctrl.leftTrigger,
                  color: AppTheme.blue,
                  onChanged: n.setLeftTrigger,
                )),
              ]),
            ),
          ),

          // ── Left stick — bottom-left ────────────────────────────────────────
          GameEl(
            id: 'left_stick', screenId: 'fps', label: 'LEFT STICK',
            naturalLeft: 10, naturalTop: h * 0.40,
            child: JoystickWidget(
              size: 110,
              deadzone: settings.joystickDeadzone,
              label: 'MOVE',
              color: AppTheme.blue,
              onChanged: n.setLeftStick,
            ),
          ),

          // ── Back / Start — centre top ───────────────────────────────────────
          GameEl(
            id: 'back_start', screenId: 'fps', label: 'BACK / START',
            naturalLeft: (w - 108) / 2, naturalTop: h * 0.12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SmallBtn(
                  label: 'BACK',
                  onDown: () => n.pressButton(PacketEncoder.btnBack),
                  onUp:   () => n.releaseButton(PacketEncoder.btnBack),
                ),
                const SizedBox(width: 14),
                _SmallBtn(
                  label: 'START',
                  onDown: () => n.pressButton(PacketEncoder.btnStart),
                  onUp:   () => n.releaseButton(PacketEncoder.btnStart),
                ),
              ],
            ),
          ),

          // ── D-Pad — centre bottom ───────────────────────────────────────────
          GameEl(
            id: 'dpad', screenId: 'fps', label: 'D-PAD',
            naturalLeft: (w - 100) / 2, naturalTop: h * 0.55,
            child: _DPad(n: n),
          ),

          // ── RB / RT — top-right ─────────────────────────────────────────────
          GameEl(
            id: 'rb_rt', screenId: 'fps', label: 'RB / RT',
            naturalLeft: w - 130, naturalTop: 0,
            child: SizedBox(
              width: 130,
              child: Row(children: [
                Expanded(child: _TriggerBar(
                  label: 'RT',
                  value: ctrl.rightTrigger,
                  color: AppTheme.accent,
                  onChanged: n.setRightTrigger,
                )),
                const SizedBox(width: 6),
                _ShoulderBtn(
                  label: 'RB',
                  onDown: () => n.pressButton(PacketEncoder.btnRB),
                  onUp:   () => n.releaseButton(PacketEncoder.btnRB),
                ),
              ]),
            ),
          ),

          // ── Face buttons (ABXY) — right ─────────────────────────────────────
          GameEl(
            id: 'face_buttons', screenId: 'fps', label: 'ABXY',
            naturalLeft: w - 128, naturalTop: h * 0.14,
            child: _FaceButtons(n: n),
          ),

          // ── Right stick / Gyro — bottom-right ──────────────────────────────
          GameEl(
            id: 'right_stick', screenId: 'fps',
            label: settings.gyroEnabled ? 'GYRO' : 'RIGHT STICK',
            naturalLeft: w - 110, naturalTop: h * 0.52,
            child: settings.gyroEnabled
                ? _GyroIndicator(x: ctrl.rightX, y: ctrl.rightY)
                : JoystickWidget(
                    size: 90,
                    deadzone: settings.joystickDeadzone,
                    label: 'AIM',
                    color: AppTheme.accent,
                    onChanged: n.setRightStick,
                  ),
          ),
        ],
      );
    });
  }
} // end _FpsScreenState


// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _FpsHeader extends ConsumerWidget {
  final ConnectionStatus status;
  final bool gyroOn;
  const _FpsHeader({required this.status, required this.gyroOn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dotClr = switch (status) {
      ConnectionStatus.connected  => AppTheme.green,
      ConnectionStatus.connecting => AppTheme.orange,
      _                           => AppTheme.textDim,
    };
    final editMode = ref.watch(editModeProvider('fps'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _Dot(color: dotClr),
          const SizedBox(width: 8),
          const Text('FPS MODE', style: TextStyle(
            fontFamily: 'monospace', color: AppTheme.textPri,
            fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 3,
          )),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: gyroOn
                  ? AppTheme.green.withOpacity(0.15)
                  : AppTheme.card,
              border: Border.all(
                color: gyroOn ? AppTheme.green : AppTheme.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              gyroOn ? 'GYRO ON' : 'GYRO OFF',
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1.5,
                color: gyroOn ? AppTheme.green : AppTheme.textDim,
              ),
            ),
          ),
          const Spacer(),
          // Edit / Done toggle
          _IconBtn(
            label: editMode ? 'DONE' : 'EDIT',
            accent: editMode ? AppTheme.green : null,
            onTap: () {
              if (editMode) {
                ref.read(selectedElementProvider('fps').notifier).state = null;
              }
              ref.read(editModeProvider('fps').notifier).state = !editMode;
            },
          ),
          const SizedBox(width: 6),
          // Switch to Racing layout (hidden in edit mode)
          if (!editMode) ...[  
            _IconBtn(
              label: 'RACE',
              onTap: () {
                ref.read(packetSenderProvider).stop();
                Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const RacingScreen()));
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
          // Close / disconnect (hidden in edit mode)
          if (!editMode)
            _IconBtn(
              icon: Icons.close_rounded,
              onTap: () async {
                ref.read(fpsControllerProvider.notifier).stopSensors();
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
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ShoulderBtn extends StatelessWidget {
  final String label;
  final VoidCallback onDown, onUp;
  const _ShoulderBtn({required this.label, required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp:   (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        width: 44, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(label, style: const TextStyle(
          fontFamily: 'monospace', fontSize: 11,
          fontWeight: FontWeight.w800, color: AppTheme.textSec,
        )),
      ),
    );
  }
}

class _TriggerBar extends StatelessWidget {
  final String label;
  final double value;
  final Color  color;
  final ValueChanged<double> onChanged;
  const _TriggerBar({required this.label, required this.value,
      required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, box) {
      return GestureDetector(
        onPanUpdate: (d) {
          onChanged((1.0 - d.localPosition.dy / box.maxHeight).clamp(0, 1));
        },
        onPanEnd: (_) => onChanged(0),
        onTapDown: (d) =>
            onChanged((1.0 - d.localPosition.dy / box.maxHeight).clamp(0, 1)),
        onTapUp:   (_) => onChanged(0),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.border),
          ),
          child: Stack(children: [
            FractionallySizedBox(
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Center(child: Text(label, style: TextStyle(
              fontFamily: 'monospace', fontSize: 10,
              fontWeight: FontWeight.w900,
              color: value > 0.3 ? Colors.white : color,
            ))),
          ]),
        ),
      );
    });
  }
}

class _FaceButtons extends StatelessWidget {
  final FpsControllerNotifier n;
  const _FaceButtons({required this.n});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _faceBtn('Y', AppTheme.orange, PacketEncoder.btnY),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _faceBtn('X', AppTheme.blue, PacketEncoder.btnX),
        const SizedBox(width: 4),
        _faceBtn('B', AppTheme.accent, PacketEncoder.btnB),
      ]),
      _faceBtn('A', AppTheme.green, PacketEncoder.btnA),
    ]);
  }

  Widget _faceBtn(String label, Color color, int mask) {
    return GestureDetector(
      onTapDown:   (_) => n.pressButton(mask),
      onTapUp:     (_) => n.releaseButton(mask),
      onTapCancel: ()  => n.releaseButton(mask),
      child: Container(
        margin: const EdgeInsets.all(2),
        width: 34, height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(0.7), width: 1.5),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'monospace', fontSize: 11,
          fontWeight: FontWeight.w900, color: color,
        )),
      ),
    );
  }
}

class _DPad extends StatelessWidget {
  final FpsControllerNotifier n;
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

  Widget _dBtn(String icon, int mask) {
    return GestureDetector(
      onTapDown:   (_) => n.pressButton(mask),
      onTapUp:     (_) => n.releaseButton(mask),
      onTapCancel: ()  => n.releaseButton(mask),
      child: Container(
        margin: const EdgeInsets.all(2),
        width: 30, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(icon, style: const TextStyle(
          color: AppTheme.textSec, fontSize: 11)),
      ),
    );
  }
}

/// Shows a circular gyro position indicator when gyro aiming is active.
class _GyroIndicator extends StatelessWidget {
  final double x, y;
  const _GyroIndicator({required this.x, required this.y});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.card,
        border: Border.all(
          color: AppTheme.green.withOpacity(0.4), width: 1.5),
      ),
      child: Stack(children: [
        // Dot showing current aim
        Positioned(
          left: 45 + x * 30 - 5,
          top:  45 - y * 30 - 5,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.green,
              boxShadow: [BoxShadow(
                color: AppTheme.green.withOpacity(0.8), blurRadius: 8)],
            ),
          ),
        ),
        const Center(child: Text('GYRO', style: TextStyle(
          fontFamily: 'monospace', fontSize: 8,
          color: AppTheme.textDim, letterSpacing: 1.5,
        ))),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final VoidCallback onDown, onUp;
  const _SmallBtn({required this.label, required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onDown(),
      onTapUp:   (_) => onUp(),
      onTapCancel: onUp,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(label, style: const TextStyle(
          fontFamily: 'monospace', fontSize: 9,
          fontWeight: FontWeight.w700, color: AppTheme.textSec,
          letterSpacing: 1.5,
        )),
      ),
    );
  }
}

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
    final p = Paint()..color = Colors.white.withOpacity(0.02)..strokeWidth = 1;
    for (double x = 0; x < size.width;  x += 44) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 44) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override
  bool shouldRepaint(_) => false;
}
