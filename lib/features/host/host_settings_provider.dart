import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HostSettingsNotifier extends AsyncNotifier<bool> {
  late SharedPreferences _prefs;
  static const _kAdbEnabled = 'host_adb_enabled';

  @override
  Future<bool> build() async {
    _prefs = await SharedPreferences.getInstance();
    // ADB enabled by default
    return _prefs.getBool(_kAdbEnabled) ?? true;
  }

  Future<void> toggleAdb(bool enabled) async {
    await _prefs.setBool(_kAdbEnabled, enabled);
    state = AsyncValue.data(enabled);
  }
}

final adbEnabledProvider = AsyncNotifierProvider<HostSettingsNotifier, bool>(
  HostSettingsNotifier.new,
);
