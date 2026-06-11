/// Shared constants used across the app.
class AppConstants {
  // Network
  static const String defaultHost = '127.0.0.1';
  static const int tcpPort = 5000; // USB mode (ADB tunnel)
  static const int udpPort = 5001; // WiFi mode

  // Legacy alias
  static const int defaultPort = tcpPort;

  // Polling defaults (overridden by GameSettings)
  static const int pollingHz = 120;
  static const int pollingMs = 1000 ~/ pollingHz;

  // Sensor defaults (overridden by GameSettings)
  static const double steeringDeadzone = 0.04;
  static const double steeringGRange = 6.5; // m/s² = full lock

  // Layouts
  static const String layoutRacing = 'racing';
  static const String layoutFps = 'fps';

  // Player
  static const int defaultPlayerId = 1;

  // Auto-reconnect
  static const int maxReconnectAttempts = 5;
  static const int reconnectBaseMs = 300; // 5 attempts taking ~4.5s total

  AppConstants._();
}
