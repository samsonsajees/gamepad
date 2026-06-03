import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ControllerState  –  immutable snapshot of every axis / button
// ─────────────────────────────────────────────────────────────────────────────

class ControllerState {
  final double leftTrigger;  // 0–1  (brake)
  final double rightTrigger; // 0–1  (throttle)
  final int    buttons;      // bitmask

  // Derived from accelerometer — used as left-stick X (steering)
  final double steeringAngle; // -1 … 1

  // Raw sensor values forwarded to server for game-side processing
  final double accelX, accelY, accelZ;
  final double gyroX,  gyroY,  gyroZ;

  const ControllerState({
    this.leftTrigger   = 0.0,
    this.rightTrigger  = 0.0,
    this.buttons       = 0,
    this.steeringAngle = 0.0,
    this.accelX = 0, this.accelY = 0, this.accelZ = 0,
    this.gyroX  = 0, this.gyroY  = 0, this.gyroZ  = 0,
  });

  ControllerState copyWith({
    double? leftTrigger,
    double? rightTrigger,
    int?    buttons,
    double? steeringAngle,
    double? accelX, double? accelY, double? accelZ,
    double? gyroX,  double? gyroY,  double? gyroZ,
  }) =>
      ControllerState(
        leftTrigger:   leftTrigger   ?? this.leftTrigger,
        rightTrigger:  rightTrigger  ?? this.rightTrigger,
        buttons:       buttons       ?? this.buttons,
        steeringAngle: steeringAngle ?? this.steeringAngle,
        accelX: accelX ?? this.accelX, accelY: accelY ?? this.accelY,
        accelZ: accelZ ?? this.accelZ, gyroX:  gyroX  ?? this.gyroX,
        gyroY:  gyroY  ?? this.gyroY,  gyroZ:  gyroZ  ?? this.gyroZ,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ControllerStateNotifier
// ─────────────────────────────────────────────────────────────────────────────

class ControllerStateNotifier extends Notifier<ControllerState> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>?     _gyroSub;

  // Low-pass filter state
  double _filteredSteering = 0.0;
  static const double _alpha = 0.25; // smaller = smoother but more lag

  @override
  ControllerState build() {
    _startSensors();
    ref.onDispose(_stopSensors);
    return const ControllerState();
  }

  // ── Sensor streaming ────────────────────────────────────────────────────

  void _startSensors() {
    // Accelerometer → steering
    // In landscape mode, gravity shifts along the Y-axis when the phone tilts
    // left/right. Dividing by gRange normalises ~±6.5 m/s² to ±1.
    _accelSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 8), // ~120 Hz
    ).listen((e) {
      // Low-pass filter to smooth jitter
      final raw = (e.y / AppConstants.steeringGRange); // negate: tilt right → positive
      _filteredSteering += _alpha * (raw - _filteredSteering);
      final steering = _applyDeadzone(_filteredSteering.clamp(-1.0, 1.0));

      state = state.copyWith(
        steeringAngle: steering,
        accelX: e.x, accelY: e.y, accelZ: e.z,
      );
    });

    // Gyroscope → forwarded raw to server for aiming / fine corrections
    _gyroSub = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 8),
    ).listen((e) {
      state = state.copyWith(gyroX: e.x, gyroY: e.y, gyroZ: e.z);
    });
  }

  void _stopSensors() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _applyDeadzone(double v) {
    const dz = AppConstants.steeringDeadzone;
    if (v.abs() < dz) return 0.0;
    final sign = v.sign;
    return sign * (v.abs() - dz) / (1.0 - dz);
  }

  // ── Controller API (called by widgets) ───────────────────────────────────

  void setLeftTrigger(double v)  => state = state.copyWith(leftTrigger:  v.clamp(0.0, 1.0));
  void setRightTrigger(double v) => state = state.copyWith(rightTrigger: v.clamp(0.0, 1.0));

  void pressButton(int mask)   => state = state.copyWith(buttons: state.buttons | mask);
  void releaseButton(int mask) => state = state.copyWith(buttons: state.buttons & ~mask);
}

final controllerStateProvider =
    NotifierProvider<ControllerStateNotifier, ControllerState>(
  ControllerStateNotifier.new,
);
