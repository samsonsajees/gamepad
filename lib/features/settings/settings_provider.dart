import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class GameSettings {
  final int    pollingRateHz;       // 60 | 90 | 120 | 240
  final double steeringDeadzone;    // 0.0 – 0.30
  final double steeringSensitivity; // 0.5 – 3.0
  final double joystickDeadzone;    // 0.0 – 0.30  (FPS sticks)
  final bool   gyroEnabled;         // FPS gyro-aiming on/off
  final double gyroSensitivity;     // 0.5 – 3.0   (FPS gyro)

  const GameSettings({
    this.pollingRateHz       = 120,
    this.steeringDeadzone    = 0.04,
    this.steeringSensitivity = 1.0,
    this.joystickDeadzone    = 0.08,
    this.gyroEnabled         = true,
    this.gyroSensitivity     = 1.2,
  });

  int get pollingMs => (1000 / pollingRateHz).round();

  GameSettings copyWith({
    int?    pollingRateHz,
    double? steeringDeadzone,
    double? steeringSensitivity,
    double? joystickDeadzone,
    bool?   gyroEnabled,
    double? gyroSensitivity,
  }) =>
      GameSettings(
        pollingRateHz:       pollingRateHz       ?? this.pollingRateHz,
        steeringDeadzone:    steeringDeadzone    ?? this.steeringDeadzone,
        steeringSensitivity: steeringSensitivity ?? this.steeringSensitivity,
        joystickDeadzone:    joystickDeadzone    ?? this.joystickDeadzone,
        gyroEnabled:         gyroEnabled         ?? this.gyroEnabled,
        gyroSensitivity:     gyroSensitivity     ?? this.gyroSensitivity,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Keys
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _K {
  static const pollingHz   = 'pollingHz';
  static const steerDz     = 'steerDz';
  static const steerSens   = 'steerSens';
  static const joyDz       = 'joyDz';
  static const gyroEnabled = 'gyroEnabled';
  static const gyroSens    = 'gyroSens';
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class SettingsNotifier extends AsyncNotifier<GameSettings> {
  late SharedPreferences _prefs;

  @override
  Future<GameSettings> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _load();
  }

  GameSettings _load() => GameSettings(
    pollingRateHz:       _prefs.getInt(_K.pollingHz)       ?? 120,
    steeringDeadzone:    _prefs.getDouble(_K.steerDz)      ?? 0.04,
    steeringSensitivity: _prefs.getDouble(_K.steerSens)    ?? 1.0,
    joystickDeadzone:    _prefs.getDouble(_K.joyDz)        ?? 0.08,
    gyroEnabled:         _prefs.getBool(_K.gyroEnabled)    ?? true,
    gyroSensitivity:     _prefs.getDouble(_K.gyroSens)     ?? 1.2,
  );

  Future<void> save(GameSettings s) async {
    await Future.wait([
      _prefs.setInt   (_K.pollingHz,   s.pollingRateHz),
      _prefs.setDouble(_K.steerDz,     s.steeringDeadzone),
      _prefs.setDouble(_K.steerSens,   s.steeringSensitivity),
      _prefs.setDouble(_K.joyDz,       s.joystickDeadzone),
      _prefs.setBool  (_K.gyroEnabled, s.gyroEnabled),
      _prefs.setDouble(_K.gyroSens,    s.gyroSensitivity),
    ]);
    state = AsyncValue.data(s);
  }

  Future<void> setPollingRate(int hz)     async => save((await future).copyWith(pollingRateHz: hz));
  Future<void> setSteerDz(double v)       async => save((await future).copyWith(steeringDeadzone: v));
  Future<void> setSteerSens(double v)     async => save((await future).copyWith(steeringSensitivity: v));
  Future<void> setJoyDz(double v)         async => save((await future).copyWith(joystickDeadzone: v));
  Future<void> setGyroEnabled(bool v)     async => save((await future).copyWith(gyroEnabled: v));
  Future<void> setGyroSensitivity(double v) async => save((await future).copyWith(gyroSensitivity: v));

  Future<void> reset() async => save(const GameSettings());
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, GameSettings>(
  SettingsNotifier.new,
);
