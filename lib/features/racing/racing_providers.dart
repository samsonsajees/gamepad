import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/constants.dart';
import '../settings/settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ControllerState
// ─────────────────────────────────────────────────────────────────────────────

class ControllerState {
  final double leftTrigger;
  final double rightTrigger;
  final int buttons;
  final double steeringAngle; // [-1, 1] mapped to left-stick X
  final double accelX, accelY, accelZ;
  final double gyroX, gyroY, gyroZ;

  const ControllerState({
    this.leftTrigger = 0,
    this.rightTrigger = 0,
    this.buttons = 0,
    this.steeringAngle = 0,
    this.accelX = 0,
    this.accelY = 0,
    this.accelZ = 0,
    this.gyroX = 0,
    this.gyroY = 0,
    this.gyroZ = 0,
  });

  ControllerState copyWith({
    double? leftTrigger,
    double? rightTrigger,
    int? buttons,
    double? steeringAngle,
    double? accelX,
    double? accelY,
    double? accelZ,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
  }) => ControllerState(
    leftTrigger: leftTrigger ?? this.leftTrigger,
    rightTrigger: rightTrigger ?? this.rightTrigger,
    buttons: buttons ?? this.buttons,
    steeringAngle: steeringAngle ?? this.steeringAngle,
    accelX: accelX ?? this.accelX,
    accelY: accelY ?? this.accelY,
    accelZ: accelZ ?? this.accelZ,
    gyroX: gyroX ?? this.gyroX,
    gyroY: gyroY ?? this.gyroY,
    gyroZ: gyroZ ?? this.gyroZ,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ControllerStateNotifier extends Notifier<ControllerState> {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  bool _sensorsRunning = false;

  // Low-pass filter state
  double _filtered = 0.0;
  static const double _alpha = 0.25;

  @override
  ControllerState build() {
    _startSensors();
    return const ControllerState();
  }

  void _startSensors() {
    _sensorsRunning = true;
    _accelSub =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 8),
        ).listen((e) {
          // Read current settings each sample so changes take effect immediately
          final settings = ref.read(settingsProvider).valueOrNull;
          final gRange = AppConstants.steeringGRange;
          final dz =
              settings?.steeringDeadzone ?? AppConstants.steeringDeadzone;
          final sens = settings?.steeringSensitivity ?? 1.0;

          // Low-pass filter  (no negation — tilt right → positive)
          final raw = e.y / gRange;
          _filtered += _alpha * (raw - _filtered);

          final steering = _applyDeadzoneSens(
            _filtered.clamp(-1.0, 1.0),
            dz,
            sens,
          );

          state = state.copyWith(
            steeringAngle: steering,
            accelX: e.x,
            accelY: e.y,
            accelZ: e.z,
          );
        });

    _gyroSub =
        gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 8),
        ).listen((e) {
          state = state.copyWith(gyroX: e.x, gyroY: e.y, gyroZ: e.z);
        });
  }

  /// Only restarts sensors if they were previously stopped.
  /// Safe to call from initState — a no-op when sensors are already running.
  void startSensors() {
    if (_sensorsRunning)
      return; // already running from build() — don't cancel/restart
    _startSensors();
  }

  void stopSensors() {
    _sensorsRunning = false;
    _accelSub?.cancel();
    _accelSub = null;
    _gyroSub?.cancel();
    _gyroSub = null;
  }

  double _applyDeadzoneSens(double v, double dz, double sens) {
    if (v.abs() < dz) return 0.0;
    final normalized = (v.abs() - dz) / (1.0 - dz) * v.sign;
    return (normalized * sens).clamp(-1.0, 1.0);
  }

  // ── Widget API ────────────────────────────────────────────────────────────

  void setLeftTrigger(double v) =>
      state = state.copyWith(leftTrigger: v.clamp(0, 1));
  void setRightTrigger(double v) =>
      state = state.copyWith(rightTrigger: v.clamp(0, 1));
  void pressButton(int mask) =>
      state = state.copyWith(buttons: state.buttons | mask);
  void releaseButton(int mask) =>
      state = state.copyWith(buttons: state.buttons & ~mask);
}

final controllerStateProvider =
    NotifierProvider<ControllerStateNotifier, ControllerState>(
      ControllerStateNotifier.new,
    );
