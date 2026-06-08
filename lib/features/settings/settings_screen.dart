import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../layout/layout_provider.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Settings is always pushed on top of a landscape gamepad screen —
    // force portrait so it reads comfortably.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    // Orientation is restored by the calling screen after Navigator.push returns.
    // We don't restore landscape here because Settings could also be reached
    // from a portrait screen in the future.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSec),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            fontFamily: 'monospace', fontSize: 13,
            fontWeight: FontWeight.w900, color: AppTheme.textPri,
            letterSpacing: 3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ref.read(settingsProvider.notifier).reset(),
            child: const Text('RESET', style: TextStyle(
              fontFamily: 'monospace', color: AppTheme.accent,
              fontSize: 11, letterSpacing: 1.5,
            )),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(
          color: AppTheme.accent, strokeWidth: 2)),
        error:   (e, _) => Center(child: Text('Error: $e',
            style: const TextStyle(color: AppTheme.accent))),
        data:    (s) => _buildBody(context, ref, s),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, GameSettings s) {
    final n = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── POLLING RATE ────────────────────────────────────────────────────
        _Section(
          title: 'POLLING RATE',
          subtitle: 'How often input is sent to the PC (higher = lower latency)',
          child: Row(
            children: [60, 90, 120, 240].map((hz) {
              final selected = s.pollingRateHz == hz;
              return Expanded(
                child: GestureDetector(
                  onTap: () => n.setPollingRate(hz),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.accent : AppTheme.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: selected ? AppTheme.accent : AppTheme.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text('${hz}Hz', style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppTheme.textSec,
                      letterSpacing: 1,
                    )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // ── RACING — STEERING ───────────────────────────────────────────────
        _Section(
          title: 'RACING — STEERING',
          child: Column(children: [
            _Slider(
              label: 'Deadzone',
              value: s.steeringDeadzone,
              min: 0.0, max: 0.30, divisions: 30,
              display: '${(s.steeringDeadzone * 100).round()}%',
              onChanged: n.setSteerDz,
            ),
            const SizedBox(height: 16),
            _Slider(
              label: 'Sensitivity',
              value: s.steeringSensitivity,
              min: 0.5, max: 3.0, divisions: 25,
              display: '${s.steeringSensitivity.toStringAsFixed(1)}×',
              onChanged: n.setSteerSens,
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── FPS — JOYSTICK ──────────────────────────────────────────────────
        _Section(
          title: 'FPS — JOYSTICK',
          child: _Slider(
            label: 'Stick Deadzone',
            value: s.joystickDeadzone,
            min: 0.0, max: 0.30, divisions: 30,
            display: '${(s.joystickDeadzone * 100).round()}%',
            onChanged: n.setJoyDz,
          ),
        ),

        const SizedBox(height: 20),

        // ── FPS — GYRO AIMING ───────────────────────────────────────────────
        _Section(
          title: 'FPS — GYRO AIMING',
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Enable Gyro Aiming', style: TextStyle(
                  fontFamily: 'monospace', color: AppTheme.textSec, fontSize: 13,
                )),
                Switch(
                  value: s.gyroEnabled,
                  onChanged: n.setGyroEnabled,
                  activeColor: AppTheme.accent,
                  trackColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected)
                        ? AppTheme.accent.withOpacity(0.3)
                        : AppTheme.border),
                ),
              ],
            ),
            if (s.gyroEnabled) ...[
              const SizedBox(height: 16),
              _Slider(
                label: 'Gyro Sensitivity',
                value: s.gyroSensitivity,
                min: 0.5, max: 3.0, divisions: 25,
                display: '${s.gyroSensitivity.toStringAsFixed(1)}×',
                onChanged: n.setGyroSensitivity,
              ),
            ],
          ]),
        ),

        const SizedBox(height: 32),

        // ── LAYOUT CUSTOMIZATION ─────────────────────────────────────────────────
        _Section(
          title: 'LAYOUT CUSTOMIZATION',
          subtitle: 'Drag, resize, and rotate controls to fit your grip.\n'
              'Tap EDIT on any gamepad screen to enter edit mode.',
          child: Column(children: [
            _LayoutResetRow(label: 'Racing Layout', screenId: 'racing'),
            const SizedBox(height: 12),
            _LayoutResetRow(label: 'FPS Layout',    screenId: 'fps'),
          ]),
        ),

        const SizedBox(height: 32),

        // ── Latency hint ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            'At ${s.pollingRateHz} Hz each packet is sent every ${s.pollingMs} ms.\n'
            'USB latency budget: ~${s.pollingMs + 2} ms total.',
            style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11,
              color: AppTheme.textDim, height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout reset row
// ─────────────────────────────────────────────────────────────────────────────

class _LayoutResetRow extends ConsumerWidget {
  final String label;
  final String screenId;
  const _LayoutResetRow({required this.label, required this.screenId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(
          fontFamily: 'monospace', color: AppTheme.textSec, fontSize: 12,
        )),
        GestureDetector(
          onTap: () async {
            await ref.read(layoutProvider.notifier).resetLayout(screenId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$label reset to defaults',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                  backgroundColor: AppTheme.surface,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Text('RESET', style: TextStyle(
              fontFamily: 'monospace', color: AppTheme.accent,
              fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5,
            )),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String  title;
  final String? subtitle;
  final Widget  child;

  const _Section({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontFamily: 'monospace', fontSize: 10,
            color: AppTheme.textDim, letterSpacing: 2.5,
          )),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(
              fontFamily: 'monospace', fontSize: 10,
              color: AppTheme.textDim, height: 1.4,
            )),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  final String   label;
  final double   value;
  final double   min;
  final double   max;
  final int      divisions;
  final String   display;
  final ValueChanged<double> onChanged;

  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(
              fontFamily: 'monospace', color: AppTheme.textSec, fontSize: 12,
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(display, style: const TextStyle(
                fontFamily: 'monospace', color: AppTheme.accent,
                fontSize: 12, fontWeight: FontWeight.w700,
              )),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor:   AppTheme.accent,
            inactiveTrackColor: AppTheme.border,
            thumbColor:         AppTheme.accent,
            overlayColor:       AppTheme.accent.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min, max: max, divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
