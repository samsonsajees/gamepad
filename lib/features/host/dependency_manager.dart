import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class DependencyManager {
  static const String _vigemRegPath =
      r'HKLM\SYSTEM\CurrentControlSet\Services\ViGEmBus';

  /// Ensures all dependencies are installed. Returns true if successful.
  static Future<bool> ensureDependencies() async {
    if (!Platform.isWindows) return true;

    debugPrint('Checking dependencies...');

    // Check for ViGEmBus
    bool vigemInstalled = await _isViGEmBusInstalled();
    if (!vigemInstalled) {
      debugPrint('ViGEmBus not found. Installing...');
      bool success = await _installViGEmBus();
      if (!success) {
        debugPrint('Failed to install ViGEmBus.');
        return false;
      }
    } else {
      debugPrint('ViGEmBus is already installed.');
    }

    return true;
  }

  static Future<bool> _isViGEmBusInstalled() async {
    try {
      final result = await Process.run('reg', ['query', _vigemRegPath]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _installViGEmBus() async {
    try {
      // Find the bundled MSI file.
      // In a built Flutter Windows app, assets are in data/flutter_assets/assets/deps
      String executableDir = p.dirname(Platform.resolvedExecutable);
      String msiPath = p.join(
        executableDir,
        'data',
        'flutter_assets',
        'assets',
        'deps',
        'ViGEmBus_1.22.0_x64_x86_arm64.exe',
      );

      // If we are in debug mode (flutter run), the path is different.
      if (!File(msiPath).existsSync()) {
        // Fallback for debug mode
        msiPath = p.join(
          Directory.current.path,
          'assets',
          'deps',
          'ViGEmBus_1.22.0_x64_x86_arm64.exe',
        );
      }

      if (!File(msiPath).existsSync()) {
        debugPrint('ViGEmBus installer not found at $msiPath');
        return false;
      }

      // Run the installer silently
      debugPrint('Running installer: "$msiPath" /quiet /norestart');
      final result = await Process.run(msiPath, [
        '/quiet',
        '/norestart',
      ]);

      debugPrint('Installer exit code: ${result.exitCode}');
      return result.exitCode == 0 ||
          result.exitCode == 3010; // 3010 means restart required
    } catch (e) {
      debugPrint('Exception installing ViGEmBus: $e');
      return false;
    }
  }

  /// Gets the path to the bundled ADB executable
  static String getAdbPath() {
    String executableDir = p.dirname(Platform.resolvedExecutable);
    String adbPath = p.join(
      executableDir,
      'data',
      'flutter_assets',
      'assets',
      'deps',
      'platform-tools',
      'adb.exe',
    );

    if (!File(adbPath).existsSync()) {
      // Fallback for debug mode
      adbPath = p.join(
        Directory.current.path,
        'assets',
        'deps',
        'platform-tools',
        'adb.exe',
      );
    }

    return adbPath;
  }
}
