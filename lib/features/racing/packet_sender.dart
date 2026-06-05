import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/packet_encoder.dart';
import '../../core/tcp_client.dart';
import '../../core/udp_client.dart';
import '../connection/connection_mode.dart';
import '../connection/connection_provider.dart';
import '../fps/fps_providers.dart';
import '../settings/settings_provider.dart';
import 'racing_providers.dart';

/// Sends controller packets at the rate configured in [GameSettings].
///
/// Supports both:
///  - Racing mode (reads from [controllerStateProvider])
///  - FPS mode    (reads from [fpsControllerProvider])
///
/// The timer is restarted automatically when the polling rate changes.
class PacketSender {
  final Ref _ref;
  Timer?    _timer;
  bool      _running = false;
  bool      _fpsMode = false;
  int       _lastHz  = 0;

  PacketSender(this._ref);

  // ── Public ────────────────────────────────────────────────────────────────

  void start()    { _fpsMode = false; _launch(); }
  void startFps() { _fpsMode = true;  _launch(); }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer  = null;
    _lastHz = 0;
  }

  void dispose() => stop();

  // ── Private ───────────────────────────────────────────────────────────────

  void _launch() {
    stop();
    _running = true;
    _scheduleWithCurrentRate();
  }

  void _scheduleWithCurrentRate() {
    if (!_running) return;
    final hz = _ref.read(settingsProvider).valueOrNull?.pollingRateHz ?? 120;
    if (hz == _lastHz && _timer != null) return;

    _timer?.cancel();
    _lastHz = hz;
    _timer  = Timer.periodic(
      Duration(milliseconds: (1000 / hz).round()),
      (_) {
        final newHz =
            _ref.read(settingsProvider).valueOrNull?.pollingRateHz ?? 120;
        if (newHz != _lastHz) { _scheduleWithCurrentRate(); return; }
        _tick();
      },
    );
  }

  void _tick() {
    final mode = _ref.read(connectionModeProvider);
    if (mode == ConnectionMode.usb) {
      final client = _ref.read(tcpClientProvider);
      if (client.status != ConnectionStatus.connected) return;
      client.send(_buildTcpPacket(client));
    } else {
      final udp = _ref.read(udpClientProvider);
      if (!udp.isConnected) return;
      udp.send(_buildUdpPayload(udp));
    }
  }

  // ── TCP builders ──────────────────────────────────────────────────────────

  Uint8List _buildTcpPacket(TcpClient c) {
    if (_fpsMode) {
      final s = _ref.read(fpsControllerProvider);
      return PacketEncoder.encodeControllerPacket(
        playerId: c.playerId, sequence: c.nextSequence(),
        leftX: s.leftX, leftY: s.leftY,
        rightX: s.rightX, rightY: s.rightY,
        leftTrigger: s.leftTrigger, rightTrigger: s.rightTrigger,
        buttons: s.buttons,
        gyroX: s.gyroX, gyroY: s.gyroY, gyroZ: s.gyroZ,
        accelX: s.accelX, accelY: s.accelY, accelZ: s.accelZ,
      );
    }
    final s = _ref.read(controllerStateProvider);
    return PacketEncoder.encodeControllerPacket(
      playerId: c.playerId, sequence: c.nextSequence(),
      leftX: s.steeringAngle, leftY: 0, rightX: 0, rightY: 0,
      leftTrigger: s.leftTrigger, rightTrigger: s.rightTrigger,
      buttons: s.buttons,
      gyroX: s.gyroX, gyroY: s.gyroY, gyroZ: s.gyroZ,
      accelX: s.accelX, accelY: s.accelY, accelZ: s.accelZ,
    );
  }

  // ── UDP builders (token prepended by UdpClient.send) ─────────────────────

  Uint8List _buildUdpPayload(UdpClient u) {
    if (_fpsMode) {
      final s = _ref.read(fpsControllerProvider);
      return PacketEncoder.encodeUdpControllerPacket(
        playerId: u.playerId, sequence: u.nextSequence(),
        leftX: s.leftX, leftY: s.leftY,
        rightX: s.rightX, rightY: s.rightY,
        leftTrigger: s.leftTrigger, rightTrigger: s.rightTrigger,
        buttons: s.buttons,
        gyroX: s.gyroX, gyroY: s.gyroY, gyroZ: s.gyroZ,
        accelX: s.accelX, accelY: s.accelY, accelZ: s.accelZ,
      );
    }
    final s = _ref.read(controllerStateProvider);
    return PacketEncoder.encodeUdpControllerPacket(
      playerId: u.playerId, sequence: u.nextSequence(),
      leftX: s.steeringAngle, leftY: 0, rightX: 0, rightY: 0,
      leftTrigger: s.leftTrigger, rightTrigger: s.rightTrigger,
      buttons: s.buttons,
      gyroX: s.gyroX, gyroY: s.gyroY, gyroZ: s.gyroZ,
      accelX: s.accelX, accelY: s.accelY, accelZ: s.accelZ,
    );
  }
}

final packetSenderProvider = Provider<PacketSender>((ref) {
  final s = PacketSender(ref);
  ref.onDispose(s.dispose);
  return s;
});
