import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../settings/settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FpsControllerState
// ─────────────────────────────────────────────────────────────────────────────

class FpsControllerState {
  final double leftX,  leftY;        // movement stick  [-1, 1]
  final double rightX, rightY;       // aim stick / gyro [-1, 1]
  final double leftTrigger;          // ADS              [0, 1]
  final double rightTrigger;         // Fire             [0, 1]
  final int    buttons;              // bitmask
  final double gyroX, gyroY, gyroZ;  // raw gyro (rad/s)
  final double accelX, accelY, accelZ;

  const FpsControllerState({
    this.leftX  = 0, this.leftY  = 0,
    this.rightX = 0, this.rightY = 0,
    this.leftTrigger  = 0, this.rightTrigger = 0,
    this.buttons = 0,
    this.gyroX = 0, this.gyroY = 0, this.gyroZ = 0,
    this.accelX = 0, this.accelY = 0, this.accelZ = 0,
  });

  FpsControllerState copyWith({
    double? leftX,  double? leftY,
    double? rightX, double? rightY,
    double? leftTrigger, double? rightTrigger,
    int?    buttons,
    double? gyroX, double? gyroY, double? gyroZ,
    double? accelX, double? accelY, double? accelZ,
  }) =>
      FpsControllerState(
        leftX: leftX ?? this.leftX,   leftY: leftY ?? this.leftY,
        rightX: rightX ?? this.rightX, rightY: rightY ?? this.rightY,
        leftTrigger:  leftTrigger  ?? this.leftTrigger,
        rightTrigger: rightTrigger ?? this.rightTrigger,
        buttons: buttons ?? this.buttons,
        gyroX: gyroX ?? this.gyroX, gyroY: gyroY ?? this.gyroY,
        gyroZ: gyroZ ?? this.gyroZ,
        accelX: accelX ?? this.accelX, accelY: accelY ?? this.accelY,
        accelZ: accelZ ?? this.accelZ,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class FpsControllerNotifier extends Notifier<FpsControllerState> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>?     _gyroSub;

  @override
  FpsControllerState build() {
    _startSensors();
    ref.onDispose(_stopSensors);
    return const FpsControllerState();
  }

  void _startSensors() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 8),
    ).listen((e) {
      state = state.copyWith(accelX: e.x, accelY: e.y, accelZ: e.z);
    });

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 8),
    ).listen((e) {
      state = state.copyWith(gyroX: e.x, gyroY: e.y, gyroZ: e.z);
      _applyGyroAim(e);
    });
  }

  void _stopSensors() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
  }

  /// Map gyroscope angular velocity (rad/s) → right-stick deflection.
  ///
  /// gyro.z = yaw  (left/right rotation when held in landscape)
  /// gyro.x = pitch (up/down tilt)
  ///
  /// A rate-based mapping gives the feel of mouse-look:
  /// fast rotation → big stick deflection → fast camera movement.
  void _applyGyroAim(GyroscopeEvent e) {
    final settings = ref.read(settingsProvider).valueOrNull;
    if (!(settings?.gyroEnabled ?? true)) return;

    final sens = settings?.gyroSensitivity ?? 1.2;
    // Typical comfortable movement is within ±5 rad/s; map to ±1
    final rx = (-e.z / 5.0 * sens).clamp(-1.0, 1.0);
    final ry = ( e.x / 5.0 * sens).clamp(-1.0, 1.0);

    state = state.copyWith(rightX: rx, rightY: ry);
  }

  // ── API called by widgets ─────────────────────────────────────────────────

  void setLeftStick(Offset v)  => state = state.copyWith(leftX: v.dx, leftY: v.dy);
  void setRightStick(Offset v) => state = state.copyWith(rightX: v.dx, rightY: v.dy);
  void setLeftTrigger(double v)  => state = state.copyWith(leftTrigger: v.clamp(0, 1));
  void setRightTrigger(double v) => state = state.copyWith(rightTrigger: v.clamp(0, 1));
  void pressButton(int mask)   => state = state.copyWith(buttons: state.buttons | mask);
  void releaseButton(int mask) => state = state.copyWith(buttons: state.buttons & ~mask);
}

final fpsControllerProvider =
    NotifierProvider<FpsControllerNotifier, FpsControllerState>(
  FpsControllerNotifier.new,
);
