/// Shared constants used across the app.
class AppConstants {
  // Network
  static const String defaultHost = '127.0.0.1';
  static const int    defaultPort = 5000;

  // Polling
  static const int    pollingHz   = 120;
  static const int    pollingMs   = 1000 ~/ pollingHz; // ~8 ms

  // Layouts
  static const String layoutRacing = 'racing';

  // Sensors – accelerometer deadzone (fraction of full range)
  static const double steeringDeadzone   = 0.04;
  // How many g units = full lock. Smaller = more sensitive.
  static const double steeringGRange     = 6.5;

  // Player ID used by this device (single-player for now)
  static const int defaultPlayerId = 1;

  AppConstants._();
}
