import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/constants.dart';

enum ConnectionStatus { disconnected, connecting, connected, reconnecting, error }

/// TCP socket wrapper with auto-reconnect.
class TcpClient {
  Socket? _socket;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  int _sequence   = 0;
  int _playerId   = 1;

  // Reconnect state
  bool    _autoReconnect      = false;
  String? _lastHost;
  int?    _lastPort;
  int     _reconnectAttempts  = 0;
  Timer?  _reconnectTimer;

  final _statusCtrl = StreamController<ConnectionStatus>.broadcast();

  // ── Public API ────────────────────────────────────────────────────────────

  Stream<ConnectionStatus> get statusStream  => _statusCtrl.stream;
  ConnectionStatus          get status        => _status;
  int                       get playerId      => _playerId;
  int nextSequence() => _sequence++;

  /// Connect. Pass [autoReconnect] = true to retry on unexpected drop.
  Future<bool> connect(
    String host,
    int    port, {
    bool autoReconnect = true,
  }) async {
    _lastHost       = host;
    _lastPort       = port;
    _autoReconnect  = autoReconnect;
    _reconnectAttempts = 0;
    return _doConnect(host, port);
  }

  void send(Uint8List bytes) {
    if (_status != ConnectionStatus.connected || _socket == null) return;
    try {
      _socket!.add(bytes);
    } catch (_) {
      _handleClose(unexpected: true);
    }
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _setStatus(ConnectionStatus.disconnected);
    await _socket?.close();
    _socket = null;
  }

  void dispose() {
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _statusCtrl.close();
    _socket?.destroy();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<bool> _doConnect(String host, int port) async {
    _setStatus(ConnectionStatus.connecting);
    try {
      _socket = await Socket.connect(host, port)
          .timeout(const Duration(seconds: 5));

      _socket!.listen(
        _onData,
        onError: (_) => _handleClose(unexpected: true),
        onDone:  ()  => _handleClose(unexpected: true),
        cancelOnError: true,
      );

      _reconnectAttempts = 0;
      _setStatus(ConnectionStatus.connected);
      return true;
    } on SocketException {
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
      return false;
    } on TimeoutException {
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
      return false;
    }
  }

  void _handleClose({bool unexpected = false}) {
    _socket = null;
    if (_autoReconnect && unexpected) {
      _setStatus(ConnectionStatus.reconnecting);
      _scheduleReconnect();
    } else {
      _setStatus(ConnectionStatus.disconnected);
    }
  }

  void _scheduleReconnect() {
    if (!_autoReconnect) return;
    if (_reconnectAttempts >= AppConstants.maxReconnectAttempts) {
      _setStatus(ConnectionStatus.error);
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(
      milliseconds: AppConstants.reconnectBaseMs * _reconnectAttempts,
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_autoReconnect && _lastHost != null && _lastPort != null) {
        _doConnect(_lastHost!, _lastPort!);
      }
    });
  }

  void _onData(Uint8List data) {
    // Server → client packets
    // 0x81  ServerAck   [length:4][0x81][success:1][player_id:4]
    // 0x82  HapticCmd   [length:4][0x82][large:f32][small:f32][ms:u32]
    if (data.length < 5) return;
    final view = ByteData.sublistView(data);
    final type = data[4];

    switch (type) {
      case 0x81: // ServerAck
        if (data.length >= 10) {
          final success = data[5];
          if (success == 1) {
            _playerId = view.getUint32(6, Endian.little);
          }
        }

      case 0x82: // HapticCmd
        if (data.length >= 17) {
          final large    = view.getFloat32(5,  Endian.little);
          final small    = view.getFloat32(9,  Endian.little);
          final durationMs = view.getUint32(13, Endian.little);
          _onHaptic(large, small, durationMs);
        }
    }
  }

  void _onHaptic(double large, double small, int ms) {
    // Vibrate on the Android device in response to game rumble events.
    // Intensity: large motor drives amplitude.
    if (large > 0.05 || small > 0.05) {
      // Vibration.vibrate(duration: ms.clamp(20, 500), amplitude: (large * 255).round());
      // Uncomment the line above and import vibration package in this file
      // if you want haptic feedback from the PC side.
    }
  }

  void _setStatus(ConnectionStatus s) {
    if (_status == s) return;
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }
}
