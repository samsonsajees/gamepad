import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
  int       _sendCount = 0;

  PacketSender(this._ref);

  // ── Public ────────────────────────────────────────────────────────────────

  bool get isRunning => _running;
  bool get isFpsMode => _fpsMode;
  int  get sendCount => _sendCount;

  // ── Public ────────────────────────────────────────────────────────────────

  void start() {
    debugPrint('[PacketSender] start() called — CALLER TRACE:');
    debugPrint(StackTrace.current.toString().split('\n').take(6).join('\n'));
    _fpsMode = false; _launch();
  }
  void startFps() {
    debugPrint('[PacketSender] startFps() called');
    _fpsMode = true;  _launch();
  }

  void stop() {
    if (_running) {
      debugPrint('[PacketSender] stop() called while RUNNING — CALLER TRACE:');
      debugPrint(StackTrace.current.toString().split('\n').take(6).join('\n'));
    }
    _running = false;
    _timer?.cancel();
    _timer  = null;
    _lastHz = 0;
    _sendCount = 0;
  }

  void dispose() => stop();

  // ── Private ───────────────────────────────────────────────────────────────

  void _launch() {
    stop();
    _running = true;
    _diagCount = 0;
    debugPrint('[PacketSender] launched, fpsMode=$_fpsMode');
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

  int _diagCount = 0;

  void _tick() {
    final mode = _ref.read(connectionModeProvider);
    if (mode == ConnectionMode.usb) {
      final client = _ref.read(tcpClientProvider);
      if (client.status != ConnectionStatus.connected) return;
      client.send(_buildTcpPacket(client));
      _sendCount++;
    } else {
      final udp = _ref.read(udpClientProvider);
      if (!udp.isConnected) {
        if (_diagCount++ % 120 == 0) {
          debugPrint('[PacketSender] WiFi tick: udp NOT connected, skipping');
        }
        return;
      }
      final payload = _buildUdpPayload(udp);
      udp.send(payload);
      _sendCount++;
      if (_diagCount++ % 120 == 0) {
        debugPrint('[PacketSender] WiFi tick: sent ${payload.length}B, '
            'fpsMode=$_fpsMode, token=${udp.token}, pid=${udp.playerId}');
      }
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
