import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';

// ── Server state providers ────────────────────────────────────────────────────

final _processProvider      = StateProvider<Process?>((ref) => null);
final _serverStatusProvider = StateProvider<String>((ref) => 'stopped');
final _playersProvider      = StateProvider<int>((ref) => 0);
final _logsProvider         = StateProvider<List<String>>((ref) => []);

// ─────────────────────────────────────────────────────────────────────────────
// HostScreen
// ─────────────────────────────────────────────────────────────────────────────

class HostScreen extends ConsumerStatefulWidget {
  const HostScreen({super.key});

  @override
  ConsumerState<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends ConsumerState<HostScreen> {
  @override
  void dispose() {
    ref.read(_processProvider)?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status  = ref.watch(_serverStatusProvider);
    final players = ref.watch(_playersProvider);
    final logs    = ref.watch(_logsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: controls ───────────────────────────────────────
            SizedBox(
              width: 300,
              child: _LeftPanel(
                status: status,
                players: players,
                onStart: _startServer,
                onStop:  _stopServer,
              ),
            ),
            const SizedBox(width: 24),
            // ── Right: slots + logs ──────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  _PlayerSlots(active: players),
                  const SizedBox(height: 16),
                  Expanded(child: _LogPanel(logs: logs)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper methods ───────────────────────────────────────────────────────

  Future<void> _killExistingServer() async {
    try {
      await Process.run(
        'taskkill',
        ['/IM', 'gamepad_server.exe', '/F'],
      );
      _addLog('> Cleared old gamepad_server.exe processes');
    } catch (_) {}
  }

  Future<bool> _hasAndroidDevice() async {
    try {
      final result = await Process.run('adb', ['devices']);
      final output = result.stdout.toString();

      return output
          .split('\n')
          .any((line) => line.trim().endsWith('\tdevice'));
    } catch (_) {
      return false;
    }
  }

  Future<void> _setupAdbReverse() async {
    try {
      await Process.run(
        'adb',
        ['reverse', '--remove', 'tcp:5000'],
      );

      final result = await Process.run(
        'adb',
        ['reverse', 'tcp:5000', 'tcp:5000'],
      );

      if (result.exitCode == 0) {
        _addLog('> ADB reverse tunnel established');
      } else {
        _addLog('ERR: Failed to create ADB reverse');
        _addLog(result.stderr.toString());
      }
    } catch (e) {
      _addLog('ERR: ADB reverse failed: $e');
    }
  }

  Future<void> _removeAdbReverse() async {
    try {
      await Process.run(
        'adb',
        ['reverse', '--remove', 'tcp:5000'],
      );

      _addLog('> ADB reverse removed');
    } catch (_) {}
  }

  // ── Server lifecycle ──────────────────────────────────────────────────────

  Future<void> _startServer() async {
    _addLog('> Starting gamepad_server.exe ...');
    ref.read(_serverStatusProvider.notifier).state = 'starting';

    try {
      await _killExistingServer();

      final hasDevice = await _hasAndroidDevice();

      if (!hasDevice) {
        _addLog('ERR: No Android device detected');
        _addLog('     Check USB cable and USB debugging');
        ref.read(_serverStatusProvider.notifier).state = 'error';
        return;
      }

      await _setupAdbReverse();

      final exe =
          '${Directory.current.path}\\rust_backend\\target\\release\\gamepad_server.exe';

      final proc = await Process.start(exe, []);

      ref.read(_processProvider.notifier).state = proc;
      ref.read(_serverStatusProvider.notifier).state = 'running';

      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _addLog(line);

        if (line.contains('"player_connected"')) {
          ref.read(_playersProvider.notifier).state++;
        } else if (line.contains('"player_disconnected"')) {
          final c = ref.read(_playersProvider);
          if (c > 0) {
            ref.read(_playersProvider.notifier).state = c - 1;
          }
        }
      });

      proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _addLog('ERR: $line'));

      proc.exitCode.then((code) {
        ref.read(_serverStatusProvider.notifier).state =
            code == 0 ? 'stopped' : 'error';

        ref.read(_processProvider.notifier).state = null;
        ref.read(_playersProvider.notifier).state = 0;

        _addLog('> Server exited (code $code)');
      });
    } catch (e) {
      ref.read(_serverStatusProvider.notifier).state = 'error';
      _addLog('ERR: $e');
    }
  }

  Future<void> _stopServer() async {
    try {
      ref.read(_processProvider)?.kill();

      await _removeAdbReverse();

      await Process.run(
        'taskkill',
        ['/IM', 'gamepad_server.exe', '/F'],
      );
    } catch (_) {}

    ref.read(_processProvider.notifier).state = null;
    ref.read(_serverStatusProvider.notifier).state = 'stopped';
    ref.read(_playersProvider.notifier).state = 0;

    _addLog('> Server stopped');
  }

  void _addLog(String line) {
    if (!mounted) return;
    final logs = ref.read(_logsProvider);
    ref.read(_logsProvider.notifier).state = [...logs, line];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left panel
// ─────────────────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final String   status;
  final int      players;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _LeftPanel({
    required this.status,
    required this.players,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final running = status == 'running';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        Row(children: [
          Container(width: 4, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GAMEPAD SERVER', style: TextStyle(
                fontFamily: 'monospace', fontSize: 17,
                fontWeight: FontWeight.w900, color: AppTheme.textPri,
                letterSpacing: 2,
              )),
              Text('WINDOWS HOST', style: TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: AppTheme.accent, letterSpacing: 2.5,
              )),
            ],
          ),
        ]),

        const SizedBox(height: 28),

        // Status badge
        _StatusBadge(status: status),
        const SizedBox(height: 16),

        // Launch / stop button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: running ? AppTheme.card : AppTheme.accent,
              foregroundColor: running ? AppTheme.textSec : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: running ? onStop : onStart,
            child: Text(
              running ? 'STOP SERVER' : 'START SERVER',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                fontSize: 12,
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),
        _UsbTunnelBox(),
        const SizedBox(height: 20),
        _RequirementsBox(),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'running'  => (AppTheme.green,  'RUNNING   · PORT 5000'),
      'starting' => (AppTheme.orange, 'STARTING …'),
      'error'    => (AppTheme.accent, 'ERROR'),
      _          => (AppTheme.textDim,'STOPPED'),
    };
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
      )),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(
        fontFamily: 'monospace', color: color,
        fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5,
      )),
    ]);
  }
}

class _UsbTunnelBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      header: '⟳  USB TUNNEL',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CodeLine('adb reverse tcp:5000 tcp:5000'),
        const SizedBox(height: 8),
        const Text(
          'Run this after plugging in the USB cable.',
          style: TextStyle(fontFamily: 'monospace', fontSize: 11,
              color: AppTheme.textDim),
        ),
      ]),
    );
  }
}

class _RequirementsBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      header: 'REQUIREMENTS',
      child: Column(children: [
        for (final r in const [
          'ViGEmBus driver installed',
          'gamepad_server.exe in same folder',
          'ADB in system PATH',
          'USB Debugging enabled on Android',
        ])
          _Req(r),
      ]),
    );
  }
}

class _Req extends StatelessWidget {
  final String text;
  const _Req(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(children: [
      const Icon(Icons.radio_button_unchecked, size: 11, color: AppTheme.border),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontFamily: 'monospace',
          fontSize: 11, color: AppTheme.textDim)),
    ]),
  );
}

class _Card extends StatelessWidget {
  final String  header;
  final Widget  child;
  const _Card({required this.header, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(header, style: const TextStyle(
          fontFamily: 'monospace', fontSize: 10,
          color: AppTheme.textDim, letterSpacing: 2,
        )),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _CodeLine extends StatelessWidget {
  final String code;
  const _CodeLine(this.code);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.bg,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(children: [
      const Text('> ', style: TextStyle(
          color: AppTheme.accent, fontFamily: 'monospace', fontSize: 12)),
      Text(code, style: const TextStyle(
          fontFamily: 'monospace', fontSize: 12, color: AppTheme.textSec)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Player slots
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerSlots extends StatelessWidget {
  final int active;
  const _PlayerSlots({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PLAYER SLOTS', style: TextStyle(
          fontFamily: 'monospace', fontSize: 10,
          color: AppTheme.textDim, letterSpacing: 2,
        )),
        const SizedBox(height: 12),
        Row(
          children: List.generate(4, (i) {
            final on = i < active;
            return Expanded(child: Container(
              margin: const EdgeInsets.only(right: 8),
              height: 60,
              decoration: BoxDecoration(
                color: on ? AppTheme.accent.withOpacity(0.12) : AppTheme.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: on ? AppTheme.accent : AppTheme.border,
                ),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(on ? Icons.sports_esports : Icons.add_rounded,
                    size: 18, color: on ? AppTheme.accent : AppTheme.border),
                const SizedBox(height: 4),
                Text('P${i + 1}', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w800,
                  color: on ? AppTheme.accent : AppTheme.border,
                )),
              ]),
            ));
          }),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log panel
// ─────────────────────────────────────────────────────────────────────────────

class _LogPanel extends ConsumerWidget {
  final List<String> logs;
  const _LogPanel({required this.logs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF060606),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            const Text('SERVER LOG', style: TextStyle(
              fontFamily: 'monospace', fontSize: 10,
              color: AppTheme.textDim, letterSpacing: 2,
            )),
            const Spacer(),
            GestureDetector(
              onTap: () =>
                  ref.read(_logsProvider.notifier).state = [],
              child: const Text('CLEAR', style: TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: AppTheme.textDim, letterSpacing: 1,
              )),
            ),
          ]),
        ),
        Container(height: 1, color: AppTheme.border),
        // Lines (newest at bottom)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: logs.length,
            itemBuilder: (ctx, i) {
              final l = logs[i];
              Color c = AppTheme.textDim;
              if (l.startsWith('ERR')) c = AppTheme.accent;
              else if (l.contains('connected'))   c = AppTheme.green;
              else if (l.contains('disconnected'))c = AppTheme.orange;
              else if (l.startsWith('>'))         c = AppTheme.textSec;
              return Text(l, style: TextStyle(
                fontFamily: 'monospace', fontSize: 11, color: c, height: 1.6,
              ));
            },
          ),
        ),
      ]),
    );
  }
}
