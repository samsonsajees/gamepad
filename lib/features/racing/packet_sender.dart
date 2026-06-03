import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/packet_encoder.dart';
import '../../core/tcp_client.dart';
import '../connection/connection_provider.dart';
import 'racing_providers.dart';

/// Sends [ControllerPacket] to the server at [AppConstants.pollingHz].
/// Holds a [Ref] so it can read the latest controller state each tick
/// without subscribing and rebuilding.
class PacketSender {
  final Ref _ref;
  Timer?    _timer;
  bool      _running = false;

  PacketSender(this._ref);

  void start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(
      Duration(milliseconds: AppConstants.pollingMs),
      (_) => _tick(),
    );
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  // ── Private ───────────────────────────────────────────────────────────────

  void _tick() {
    final client = _ref.read(tcpClientProvider);
    if (client.status != ConnectionStatus.connected) return;

    final ctrl = _ref.read(controllerStateProvider);

    final bytes = PacketEncoder.encodeControllerPacket(
      playerId:     client.playerId,
      sequence:     client.nextSequence(),
      // Gyro steering on left-stick X axis
      leftX:        ctrl.steeringAngle,
      leftY:        0.0,
      rightX:       0.0,
      rightY:       0.0,
      leftTrigger:  ctrl.leftTrigger,
      rightTrigger: ctrl.rightTrigger,
      buttons:      ctrl.buttons,
      gyroX:        ctrl.gyroX,
      gyroY:        ctrl.gyroY,
      gyroZ:        ctrl.gyroZ,
      accelX:       ctrl.accelX,
      accelY:       ctrl.accelY,
      accelZ:       ctrl.accelZ,
    );

    client.send(bytes);
  }
}

final packetSenderProvider = Provider<PacketSender>((ref) {
  final sender = PacketSender(ref);
  ref.onDispose(sender.dispose);
  return sender;
});
