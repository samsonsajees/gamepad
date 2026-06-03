import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tcp_client.dart';
import '../../shared/theme.dart';
import '../racing/racing_screen.dart';
import 'connection_provider.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _hostCtrl = TextEditingController(text: '127.0.0.1');
  final _portCtrl = TextEditingController(text: '5000');
  String? _errorMsg;

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connAsync = ref.watch(connectionNotifierProvider);
    final isConnecting = connAsync.isLoading;

    // Navigate to racing screen once connected
    ref.listen<AsyncValue<ConnectionStatus>>(
      connectionNotifierProvider,
      (_, next) {
        if (next.valueOrNull == ConnectionStatus.connected) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RacingScreen()),
          );
        }
        if (next.valueOrNull == ConnectionStatus.error) {
          setState(() => _errorMsg = 'Connection failed. Is the server running?');
        }
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogo(),
              const SizedBox(height: 32),
              _buildUsbInstructions(),
              const SizedBox(height: 28),
              _buildForm(isConnecting),
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                _buildError(_errorMsg!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Logo ─────────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 5,
          height: 48,
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
                fontFamily: 'monospace',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPri,
                letterSpacing: 3,
              ),
            ),
            Text(
              'RACING EDITION  ·  USB MODE',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: AppTheme.accent.withOpacity(0.8),
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── ADB / USB instructions ─────────────────────────────────────────────

  Widget _buildUsbInstructions() {
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
          const Row(
            children: [
              Icon(Icons.usb_rounded, color: AppTheme.accent, size: 15),
              SizedBox(width: 8),
              Text(
                'USB SETUP',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _step('1', 'Enable USB Debugging on your Android device'),
          _step('2', 'Connect USB cable to the Windows PC'),
          _step('3', 'Install ViGEmBus driver on Windows'),
          _step('4', 'Run in Windows Terminal:\n'
              'adb reverse tcp:5000 tcp:5000'),
          _step('5', 'Launch  gamepad_server.exe  on Windows'),
          _step('6', 'Tap CONNECT below  ↓'),
        ],
      ),
    );
  }

  Widget _step(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              n,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSec,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppTheme.textSec,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Connection form ───────────────────────────────────────────────────────

  Widget _buildForm(bool isConnecting) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _field(_hostCtrl, 'HOST', '127.0.0.1'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                _portCtrl, 'PORT', '5000',
                inputType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isConnecting ? AppTheme.card : AppTheme.accent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isConnecting
                  ? []
                  : [
                      BoxShadow(
                        color: AppTheme.accent.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: isConnecting ? null : _onConnect,
                child: Center(
                  child: isConnecting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppTheme.textSec,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'CONNECT',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.5,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType inputType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: AppTheme.textDim,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: inputType,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppTheme.textPri,
            fontSize: 14,
          ),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildError(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.accent, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.accent,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onConnect() async {
    setState(() => _errorMsg = null);
    final host = _hostCtrl.text.trim().isEmpty
        ? '127.0.0.1'
        : _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 5000;
    await ref.read(connectionNotifierProvider.notifier).connect(host, port);
  }
}
