import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Connection states
enum ConnectionStatus { disconnected, connecting, connected, error }

/// Thin TCP socket wrapper used by the Android controller app.
///
/// Responsibilities:
///  - Connect / disconnect
///  - Fire-and-forget packet sends (no await needed in the hot loop)
///  - Expose [statusStream] for UI to react to connection changes
///  - Track sequence number and player ID
class TcpClient {
  Socket? _socket;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  int _sequence = 0;
  int _playerId = 1;

  final _statusCtrl = StreamController<ConnectionStatus>.broadcast();

  // ── Public API ────────────────────────────────────────────────────────────

  Stream<ConnectionStatus> get statusStream => _statusCtrl.stream;
  ConnectionStatus          get status       => _status;
  int                       get playerId     => _playerId;

  int nextSequence() => _sequence++;

  /// Open a TCP connection. Returns true on success.
  Future<bool> connect(String host, int port) async {
    if (_status == ConnectionStatus.connected) return true;

    _setStatus(ConnectionStatus.connecting);
    try {
      _socket = await Socket.connect(host, port)
          .timeout(const Duration(seconds: 5));

      _socket!.listen(
        _onServerData,
        onError: (_) => _handleClose(),
        onDone: _handleClose,
        cancelOnError: true,
      );

      _setStatus(ConnectionStatus.connected);
      return true;
    } on SocketException catch (_) {
      _setStatus(ConnectionStatus.error);
      return false;
    } on TimeoutException catch (_) {
      _setStatus(ConnectionStatus.error);
      return false;
    }
  }

  /// Send raw bytes. No-op if not connected.
  void send(Uint8List bytes) {
    if (_status != ConnectionStatus.connected || _socket == null) return;
    try {
      _socket!.add(bytes);
    } catch (_) {
      _handleClose();
    }
  }

  Future<void> disconnect() async {
    _setStatus(ConnectionStatus.disconnected);
    await _socket?.close();
    _socket = null;
  }

  void dispose() {
    _statusCtrl.close();
    _socket?.destroy();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _onServerData(Uint8List data) {
    // Server → client:
    //   0x81  ServerAck  [success:1][player_id:4]
    //   0x82  HapticCmd  (future)
    if (data.length >= 10) {
      final view = ByteData.sublistView(data);
      final contentLen = view.getUint32(0, Endian.little);
      if (contentLen >= 5 && data[4] == 0x81 && data[5] == 1) {
        _playerId = view.getUint32(6, Endian.little);
      }
    }
  }

  void _handleClose() {
    _socket = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void _setStatus(ConnectionStatus s) {
    if (_status == s) return;
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }
}
