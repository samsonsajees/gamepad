import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'tcp_client.dart'; // for ConnectionStatus

/// UDP socket client used in WiFi mode.
///
/// Prepends the 4-byte session [token] to every outgoing packet so the
/// Rust UDP server can authenticate it.
///
/// No connection state on UDP — "connected" just means we have a valid
/// destination address and token.
class UdpClient {
  RawDatagramSocket? _socket;
  InternetAddress?   _serverAddr;
  int                _serverPort = 5001;
  int                _token      = 0;
  bool               _connected  = false;
  int                _sequence   = 0;
  int                _playerId   = 1;

  final _statusCtrl = StreamController<ConnectionStatus>.broadcast();

  // ── Public API ────────────────────────────────────────────────────────────

  Stream<ConnectionStatus> get statusStream => _statusCtrl.stream;
  bool                      get isConnected  => _connected;
  int                       get token        => _token;
  int                       get playerId     => _playerId;
  int nextSequence() => _sequence++;

  ConnectionStatus get status =>
      _connected ? ConnectionStatus.connected : ConnectionStatus.disconnected;

  /// Open the local UDP socket and record the server endpoint.
  /// [host] is the Windows PC's LAN IP.
  /// [port] is 5001 by default.
  /// [token] is read from the QR code / manual entry.
  Future<bool> connect(String host, int port, int token) async {
    try {
      _serverAddr = InternetAddress(host);
      _serverPort = port;
      _token      = token;
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // OS picks a local port
      );
      _connected = true;
      _setStatus(ConnectionStatus.connected);
      return true;
    } catch (_) {
      _setStatus(ConnectionStatus.error);
      return false;
    }
  }

  /// Send [payload] (content only — no token, no length prefix).
  /// This method prepends the 4-byte session token automatically.
  ///
  /// Use PacketEncoder.encodeUdpHandshake / encodeUdpControllerPacket
  /// to build the payload.
  void send(Uint8List payload) {
    if (!_connected || _socket == null || _serverAddr == null) return;
    final packet = Uint8List(4 + payload.length);
    ByteData.sublistView(packet).setUint32(0, _token, Endian.little);
    packet.setRange(4, packet.length, payload);
    try {
      _socket!.send(packet, _serverAddr!, _serverPort);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _connected = false;
    _socket?.close();
    _socket = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void dispose() {
    _connected = false;
    _statusCtrl.close();
    _socket?.close();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _setStatus(ConnectionStatus s) {
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }
}
