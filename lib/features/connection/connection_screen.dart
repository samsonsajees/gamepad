import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/tcp_client.dart';
import '../../shared/theme.dart';
import '../racing/racing_screen.dart';
import 'connection_mode.dart';
import 'connection_provider.dart';
import 'wifi_connect_screen.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});
  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _hostCtrl = TextEditingController(text: AppConstants.defaultHost);
  final _portCtrl = TextEditingController(text: '${AppConstants.tcpPort}');
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connAsync = ref.watch(connectionNotifierProvider);
    final isLoading = connAsync.isLoading;

    ref.listen<AsyncValue<ConnectionStatus>>(
      connectionNotifierProvider,
      (_, next) {
        if (next.valueOrNull == ConnectionStatus.connected) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RacingScreen()),
          );
        }
        if (next.valueOrNull == ConnectionStatus.error) {
          setState(() => _errorMsg = 'Connection failed — is the server running?');
        }
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _buildLogo(),
            ),
            const SizedBox(height: 24),

            // ── Tabs ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
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
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textSec,
                  tabs: const [
                    Tab(icon: Icon(Icons.usb_rounded, size: 16), text: 'USB'),
                    Tab(icon: Icon(Icons.wifi_rounded,  size: 16), text: 'WiFi'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Tab body ───────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _UsbTab(
                    hostCtrl:  _hostCtrl,
                    portCtrl:  _portCtrl,
                    isLoading: isLoading,
                    errorMsg:  _errorMsg,
                    onConnect: _connectUsb,
                  ),
                  const WifiConnectScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 5, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MOBILE GAMEPAD',
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 20,
                fontWeight: FontWeight.w900, color: AppTheme.textPri,
                letterSpacing: 3,
              ),
            ),
            Text(
              'RACING + FPS EDITION',
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 10,
                color: AppTheme.accent.withOpacity(0.8), letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _connectUsb() async {
    setState(() => _errorMsg = null);
    final host = _hostCtrl.text.trim().isEmpty
        ? AppConstants.defaultHost
        : _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? AppConstants.tcpPort;
    await ref.read(connectionNotifierProvider.notifier).connectUsb(host, port);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// USB Tab
// ─────────────────────────────────────────────────────────────────────────────

class _UsbTab extends StatelessWidget {
  final TextEditingController hostCtrl;
  final TextEditingController portCtrl;
  final bool    isLoading;
  final String? errorMsg;
  final VoidCallback onConnect;

  const _UsbTab({
    required this.hostCtrl,
    required this.portCtrl,
    required this.isLoading,
    required this.errorMsg,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _usbInstructions(),
          const SizedBox(height: 24),
          _form(context),
          if (errorMsg != null) ...[
            const SizedBox(height: 12),
            _errorBox(errorMsg!),
          ],
        ],
      ),
    );
  }

  Widget _usbInstructions() {
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
          const Row(children: [
            Icon(Icons.usb_rounded, color: AppTheme.accent, size: 14),
            SizedBox(width: 8),
            Text('USB SETUP', style: TextStyle(
              fontFamily: 'monospace', color: AppTheme.accent,
              fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.5,
            )),
          ]),
          const SizedBox(height: 12),
          for (final e in const [
            ('1', 'Enable USB Debugging on Android'),
            ('2', 'Connect USB cable to Windows PC'),
            ('3', 'Install ViGEmBus driver on Windows'),
            ('4', 'Run:  adb reverse tcp:5000 tcp:5000'),
            ('5', 'Launch gamepad_server.exe on Windows'),
            ('6', 'Tap CONNECT below ↓'),
          ])
            _step(e.$1, e.$2),
        ],
      ),
    );
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(n, style: const TextStyle(
              fontFamily: 'monospace', fontSize: 10,
              fontWeight: FontWeight.w700, color: AppTheme.textSec,
            )),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(
            fontFamily: 'monospace', fontSize: 12,
            color: AppTheme.textSec, height: 1.5,
          ))),
        ],
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(flex: 3, child: _field(hostCtrl, 'HOST', AppConstants.defaultHost)),
          const SizedBox(width: 12),
          Expanded(child: _field(portCtrl, 'PORT', '5000',
              type: TextInputType.number)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 52,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isLoading ? AppTheme.card : AppTheme.accent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isLoading ? [] : [BoxShadow(
                color: AppTheme.accent.withOpacity(0.4),
                blurRadius: 18, offset: const Offset(0, 4),
              )],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: isLoading ? null : onConnect,
                child: Center(child: isLoading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: AppTheme.textSec, strokeWidth: 2))
                  : const Text('CONNECT', style: TextStyle(
                      fontFamily: 'monospace', color: Colors.white,
                      fontSize: 14, fontWeight: FontWeight.w900,
                      letterSpacing: 3.5))),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint,
      {TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontFamily: 'monospace', fontSize: 10,
          color: AppTheme.textDim, letterSpacing: 2,
        )),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl, keyboardType: type,
          style: const TextStyle(fontFamily: 'monospace',
              color: AppTheme.textPri, fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppTheme.accent, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(
          fontFamily: 'monospace', color: AppTheme.accent, fontSize: 11))),
      ]),
    );
  }
}
