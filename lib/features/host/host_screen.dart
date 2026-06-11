import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../shared/theme.dart';

// ── Server state ──────────────────────────────────────────────────────────────

final _processProvider = StateProvider<Process?>((ref) => null);
final _statusProvider = StateProvider<String>((ref) => 'stopped');
final _playersProvider = StateProvider<int>((ref) => 0);
final _logsProvider = StateProvider<List<String>>((ref) => []);

// Session info emitted by the Rust server on startup
final _tcpPortProvider = StateProvider<int>((ref) => 5000);
final _udpPortProvider = StateProvider<int>((ref) => 5001);
final _tokenProvider = StateProvider<int>((ref) => 0);
final _localIpProvider = StateProvider<String>((ref) => '…');

// ─────────────────────────────────────────────────────────────────────────────
// HostScreen
// ─────────────────────────────────────────────────────────────────────────────

class HostScreen extends ConsumerStatefulWidget {
  const HostScreen({super.key});
  @override
  ConsumerState<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends ConsumerState<HostScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _detectLocalIp();
  }

  @override
  void dispose() {
    ref.read(_processProvider)?.kill();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _detectLocalIp() async {
    try {
      // Use a UDP socket trick to find the actual LAN-routable IP.
      // Connecting UDP to an external IP doesn't send any packets —
      // it just selects the right local interface.
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      // "Connect" to a public IP to pick the right routing interface
      socket.close();

      // Fallback: iterate interfaces and prefer private-range addresses
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      String? best;
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final a = addr.address;
          // Prefer 192.168.x.x > 10.x.x.x > 172.16-31.x.x > anything else
          if (a.startsWith('192.168.')) {
            best = a;
            break;
          }
          if (a.startsWith('10.')) best ??= a;
          if (RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(a)) best ??= a;
          best ??= a;
        }
        if (best?.startsWith('192.168.') == true) break;
      }
      ref.read(_localIpProvider.notifier).state = best ?? 'Unknown';
    } catch (_) {
      ref.read(_localIpProvider.notifier).state = 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(_statusProvider);
    final players = ref.watch(_playersProvider);
    final logs = ref.watch(_logsProvider);
    final token = ref.watch(_tokenProvider);
    final ip = ref.watch(_localIpProvider);
    final udpPort = ref.watch(_udpPortProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left panel ───────────────────────────────────────────
            SizedBox(
              width: 290,
              child: _LeftPanel(
                status: status,
                players: players,
                onStart: _startServer,
                onStop: _stopServer,
              ),
            ),
            const SizedBox(width: 24),
            // ── Right panel: tabs ────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      indicator: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textSec,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.people_rounded, size: 15),
                          text: 'PLAYERS',
                        ),
                        Tab(
                          icon: Icon(Icons.wifi_rounded, size: 15),
                          text: 'WiFi',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        // Players tab
                        Column(
                          children: [
                            _PlayerSlots(active: players),
                            const SizedBox(height: 16),
                            Expanded(child: _LogPanel(logs: logs)),
                          ],
                        ),
                        // WiFi tab
                        _WifiPanel(
                          ip: ip,
                          udpPort: udpPort,
                          token: token,
                          running: status == 'running',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Server lifecycle ──────────────────────────────────────────────────────

  /// Returns the first existing path for gamepad_server.exe, or the first
  /// candidate if none exist (so the error message is still meaningful).
  String _findServerExe() {
    final root = Directory.current.path;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir\\gamepad_server.exe', // production: same folder as Flutter exe
      '$root\\gamepad_server.exe', // manually copied to project root
      '$root\\rust_backend\\target\\release\\gamepad_server.exe', // dev build in-place
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return candidates.last; // fall through — will fail with a clear error
  }

  Future<void> _startServer() async {
    _addLog('> Starting gamepad_server.exe …');
    ref.read(_statusProvider.notifier).state = 'starting';

    try {
      final exe = _findServerExe();
      _addLog('> Resolved: $exe');
      final proc = await Process.start(exe, []);
      ref.read(_processProvider.notifier).state = proc;
      ref.read(_statusProvider.notifier).state = 'running';

      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleServerLine);

      proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => _addLog('ERR: $l'));

      proc.exitCode.then((code) {
        ref.read(_statusProvider.notifier).state = code == 0
            ? 'stopped'
            : 'error';
        ref.read(_processProvider.notifier).state = null;
        ref.read(_playersProvider.notifier).state = 0;
        _addLog('> Server exited (code $code)');
      });

      // Automatically set up USB tunnel so Android can reach the server.
      await _setupUsbTunnel();
      // Add Windows Firewall rule so Android WiFi packets can reach the UDP server.
      await _addFirewallRule();
    } catch (e) {
      ref.read(_statusProvider.notifier).state = 'error';
      _addLog('ERR: Could not launch gamepad_server.exe');
      _addLog('     Expected at one of:');
      _addLog('       • same folder as gamepad_claude.exe');
      _addLog('       • project root');
      _addLog('       • rust_backend\\target\\release\\');
    }
  }

  Future<void> _setupUsbTunnel() async {
    _addLog('> Setting up USB tunnel (adb reverse tcp:5000 tcp:5000) …');
    try {
      final result = await Process.run('adb', [
        'reverse',
        'tcp:5000',
        'tcp:5000',
      ], runInShell: true);
      if (result.exitCode == 0) {
        _addLog('> USB tunnel ready — Android can connect via USB');
      } else {
        final err = (result.stderr as String).trim();
        _addLog('WARN: adb reverse failed (exit ${result.exitCode})');
        if (err.isNotEmpty) _addLog('     $err');
        _addLog(
          '     Connect USB cable and ensure ADB is in PATH, then retry.',
        );
      }
    } catch (_) {
      _addLog('WARN: adb not found — USB tunnel not configured.');
      _addLog('     Install Android Platform Tools and add to PATH.');
    }
  }

  void _handleServerLine(String line) {
    _addLog(line);
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      switch (json['event']) {
        case 'session_info':
          ref.read(_tcpPortProvider.notifier).state = json['tcp_port'] as int;
          ref.read(_udpPortProvider.notifier).state = json['udp_port'] as int;
          ref.read(_tokenProvider.notifier).state = json['token'] as int;
        case 'player_connected':
          ref.read(_playersProvider.notifier).state++;
        case 'player_disconnected':
          final c = ref.read(_playersProvider);
          if (c > 0) ref.read(_playersProvider.notifier).state = c - 1;
      }
    } catch (_) {}
  }

  Future<void> _stopServer() async {
    ref.read(_processProvider)?.kill();
    ref.read(_processProvider.notifier).state = null;
    ref.read(_statusProvider.notifier).state = 'stopped';
    ref.read(_playersProvider.notifier).state = 0;
    ref.read(_tokenProvider.notifier).state = 0;
    _addLog('> Server stopped');
    await _tearDownUsbTunnel();
    await _removeFirewallRule();
  }

  Future<void> _addFirewallRule() async {
    _addLog('> Adding Windows Firewall rule for UDP port 5001 …');
    try {
      // Remove any stale rule first (ignore errors)
      await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'delete',
        'rule',
        'name=GamepadServerUDP',
      ], runInShell: true);
      final result = await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'add',
        'rule',
        'name=GamepadServerUDP',
        'protocol=UDP',
        'dir=in',
        'localport=5001',
        'action=allow',
      ], runInShell: true);
      if (result.exitCode == 0) {
        _addLog('> Firewall rule added — WiFi ready');
      } else {
        _addLog('WARN: Firewall rule failed (run as Administrator?)');
        _addLog('     UDP WiFi may be blocked. Try running the app as Admin.');
      }
    } catch (_) {
      _addLog('WARN: Could not add firewall rule.');
    }
  }

  Future<void> _removeFirewallRule() async {
    try {
      await Process.run('netsh', [
        'advfirewall',
        'firewall',
        'delete',
        'rule',
        'name=GamepadServerUDP',
      ], runInShell: true);
      _addLog('> Firewall rule removed');
    } catch (_) {}
  }

  Future<void> _tearDownUsbTunnel() async {
    _addLog('> Removing USB tunnel (adb reverse --remove tcp:5000) …');
    try {
      final result = await Process.run('adb', [
        'reverse',
        '--remove',
        'tcp:5000',
      ], runInShell: true);
      if (result.exitCode == 0) {
        _addLog('> USB tunnel removed');
      } else {
        final err = (result.stderr as String).trim();
        _addLog('WARN: adb reverse --remove failed (exit ${result.exitCode})');
        if (err.isNotEmpty) _addLog('     $err');
      }
    } catch (_) {
      _addLog('WARN: adb not found — tunnel may still be active on device.');
    }
  }

  void _addLog(String line) {
    if (!mounted) return;
    final logs = ref.read(_logsProvider);
    ref.read(_logsProvider.notifier).state = [...logs, line];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left panel (server controls)
// ─────────────────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final String status;
  final int players;
  final Future<void> Function() onStart, onStop;
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
        Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GAMEPAD SERVER',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPri,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'WINDOWS HOST',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppTheme.accent,
                    letterSpacing: 2.5,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),
        _StatusBadge(status: status),
        const SizedBox(height: 14),

        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: running ? AppTheme.card : AppTheme.accent,
              foregroundColor: running ? AppTheme.textSec : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
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

        const SizedBox(height: 24),
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
      'running' => (AppTheme.green, 'RUNNING'),
      'starting' => (AppTheme.orange, 'STARTING …'),
      'error' => (AppTheme.accent, 'ERROR'),
      _ => (AppTheme.textDim, 'STOPPED'),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

class _RequirementsBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _Card(
    header: 'REQUIREMENTS',
    child: Column(
      children: [
        for (final r in const [
          'ViGEmBus driver installed',
          'gamepad_server.exe in same folder',
          'ADB in system PATH',
          'USB Debugging on Android',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                const Icon(
                  Icons.radio_button_unchecked,
                  size: 11,
                  color: AppTheme.border,
                ),
                const SizedBox(width: 8),
                Text(
                  r,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppTheme.textDim,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WiFi tab — QR code + session token
// ─────────────────────────────────────────────────────────────────────────────

class _WifiPanel extends StatelessWidget {
  final String ip;
  final int udpPort, token;
  final bool running;
  const _WifiPanel({
    required this.ip,
    required this.udpPort,
    required this.token,
    required this.running,
  });

  String get _qrData => 'gamepad://$ip:$udpPort?token=$token';

  @override
  Widget build(BuildContext context) {
    if (!running || token == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppTheme.textDim,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'Start the server to generate\na WiFi QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.textDim,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // QR code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: _qrData,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 24),

        // Connection details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WIFI CONNECTION',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: AppTheme.textDim,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 16),
              _InfoRow(label: 'PC IP', value: ip),
              _InfoRow(label: 'UDP PORT', value: '$udpPort'),
              _InfoRow(label: 'TOKEN', value: '$token', copyable: true),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                ),
                child: const Text(
                  '1. Both devices on the same WiFi\n'
                  '2. Scan QR code in the Android app\n'
                  '   (WiFi tab → Scan QR Code)\n'
                  '3. Or enter IP + Token manually',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppTheme.textSec,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool copyable;
  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppTheme.textDim,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: AppTheme.textPri,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (copyable) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: value)),
              child: const Icon(
                Icons.copy_rounded,
                size: 16,
                color: AppTheme.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Player slots
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerSlots extends StatelessWidget {
  final int active;
  const _PlayerSlots({required this.active});

  @override
  Widget build(BuildContext context) {
    return _Card(
      header: 'PLAYER SLOTS',
      child: Row(
        children: List.generate(4, (i) {
          final on = i < active;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              height: 58,
              decoration: BoxDecoration(
                color: on ? AppTheme.accent.withOpacity(0.12) : AppTheme.card,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: on ? AppTheme.accent : AppTheme.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    on ? Icons.sports_esports : Icons.add_rounded,
                    size: 18,
                    color: on ? AppTheme.accent : AppTheme.border,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'P${i + 1}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: on ? AppTheme.accent : AppTheme.border,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'SERVER LOG',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppTheme.textDim,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => ref.read(_logsProvider.notifier).state = [],
                  child: const Text(
                    'CLEAR',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: AppTheme.textDim,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppTheme.border),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final l = logs[i];
                Color c = AppTheme.textDim;
                if (l.startsWith('ERR'))
                  c = AppTheme.accent;
                else if (l.contains('"player_connected"'))
                  c = AppTheme.green;
                else if (l.contains('"player_disconnected"'))
                  c = AppTheme.orange;
                else if (l.startsWith('>'))
                  c = AppTheme.textSec;
                return Text(
                  l,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: c,
                    height: 1.6,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String header;
  final Widget child;
  const _Card({required this.header, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: AppTheme.textDim,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
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
    child: Row(
      children: [
        const Text(
          '> ',
          style: TextStyle(
            color: AppTheme.accent,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        Text(
          code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: AppTheme.textSec,
          ),
        ),
      ],
    ),
  );
}
