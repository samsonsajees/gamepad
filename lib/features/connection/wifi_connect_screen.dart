import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/tcp_client.dart';
import '../../shared/theme.dart';
import '../racing/racing_screen.dart';
import 'connection_provider.dart';

class WifiConnectScreen extends ConsumerStatefulWidget {
  const WifiConnectScreen({super.key});
  @override
  ConsumerState<WifiConnectScreen> createState() => _WifiConnectScreenState();
}

class _WifiConnectScreenState extends ConsumerState<WifiConnectScreen> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _scanning = false;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ConnectionStatus>>(connectionNotifierProvider, (
      _,
      next,
    ) {
      if (next.valueOrNull == ConnectionStatus.connected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RacingScreen()),
        );
      }
      if (next.valueOrNull == ConnectionStatus.error) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'WiFi connection failed. Check IP and token.';
        });
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _wifiInstructions(),
          const SizedBox(height: 20),

          // ── QR scanner / manual toggle ──────────────────────────────
          if (_scanning) _qrScanner() else _scanButton(),

          const SizedBox(height: 20),
          _divider('OR ENTER MANUALLY'),
          const SizedBox(height: 16),
          _manualForm(),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            _errorBox(_errorMsg!),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── WiFi instructions ──────────────────────────────────────────────────────

  Widget _wifiInstructions() {
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
              Icon(Icons.wifi_rounded, color: AppTheme.blue, size: 14),
              SizedBox(width: 8),
              Text(
                'WIFI SETUP',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: AppTheme.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in const [
            ('1', 'Both devices on the same WiFi network'),
            ('2', 'Start the Server in PC'),
            (
              '4',
              'Scan the QR code shown there,\nor enter the IP + token manually',
            ),
            ('5', 'Tap CONNECT VIA WIFI below ↓'),
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
            width: 20,
            height: 20,
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
                fontSize: 10,
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

  // ── QR scanner ─────────────────────────────────────────────────────────────

  Widget _scanButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.blue,
          side: const BorderSide(color: AppTheme.blue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => setState(() => _scanning = true),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
        label: const Text(
          'SCAN QR CODE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _qrScanner() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            child: MobileScanner(
              onDetect: (capture) {
                final raw = capture.barcodes.firstOrNull?.rawValue;
                if (raw != null) _parseQr(raw);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _scanning = false),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSec),
          ),
        ),
      ],
    );
  }

  void _parseQr(String raw) {
    // Format: gamepad://192.168.1.5:5001?token=1234567890
    try {
      final normalized = raw.replaceFirst('gamepad://', 'http://');
      final uri = Uri.parse(normalized);
      _ipCtrl.text = uri.host;
      _portCtrl.text = uri.port.toString();
      _tokenCtrl.text = uri.queryParameters['token'] ?? '';
      setState(() => _scanning = false);
    } catch (_) {
      setState(() {
        _scanning = false;
        _errorMsg = 'Could not parse QR code. Try manual entry.';
      });
    }
  }

  // ── Manual entry form ──────────────────────────────────────────────────────

  Widget _manualForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _field(_ipCtrl, 'PC IP ADDRESS', '192.168.1.x'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                _portCtrl,
                'PORT',
                'e.g. 53912',
                type: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _field(
          _tokenCtrl,
          'SESSION TOKEN',
          'shown in Windows app',
          type: TextInputType.number,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _isLoading ? AppTheme.card : AppTheme.blue,
              borderRadius: BorderRadius.circular(8),
              boxShadow: _isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: AppTheme.blue.withOpacity(0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _isLoading ? null : _connectWifi,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppTheme.textSec,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'CONNECT VIA WIFI',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
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
    TextInputType type = TextInputType.text,
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
          keyboardType: type,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppTheme.textPri,
            fontSize: 13,
          ),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _divider(String label) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: AppTheme.textDim,
              letterSpacing: 2,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.border)),
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

  Future<void> _connectWifi() async {
    setState(() {
      _errorMsg = null;
      _isLoading = true;
    });
    final host = _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 0;
    final token = int.tryParse(_tokenCtrl.text.trim()) ?? 0;

    if (host.isEmpty || port == 0 || token == 0) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Enter the PC IP address, port, and session token.';
      });
      return;
    }

    await ref
        .read(connectionNotifierProvider.notifier)
        .connectWifi(host, port, token);
    if (mounted) setState(() => _isLoading = false);
  }
}
