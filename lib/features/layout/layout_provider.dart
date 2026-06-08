import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'layout_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Storage keys
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _K {
  static const racingLayout = 'layout_racing';
  static const fpsLayout    = 'layout_fps';
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout notifier  — loads & persists both screen layouts
// ─────────────────────────────────────────────────────────────────────────────

class LayoutNotifier extends AsyncNotifier<Map<String, ScreenLayout>> {
  late SharedPreferences _prefs;

  @override
  Future<Map<String, ScreenLayout>> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _load();
  }

  Map<String, ScreenLayout> _load() {
    ScreenLayout _read(String key) {
      final s = _prefs.getString(key);
      if (s == null) return const ScreenLayout();
      try {
        return ScreenLayout.fromJsonString(s);
      } catch (_) {
        return const ScreenLayout();
      }
    }

    return {
      'racing': _read(_K.racingLayout),
      'fps':    _read(_K.fpsLayout),
    };
  }

  String _key(String screenId) =>
      screenId == 'racing' ? _K.racingLayout : _K.fpsLayout;

  Future<void> updateElement(String screenId, ElementLayout el) async {
    final current = state.valueOrNull ?? {};
    final screen  = (current[screenId] ?? const ScreenLayout()).withElement(el);
    // Update in-memory state immediately so every watcher sees the new
    // position in the very next frame — before the disk write completes.
    state = AsyncValue.data({...current, screenId: screen});
    // Persist to SharedPreferences in the background.
    await _prefs.setString(_key(screenId), screen.toJsonString());
  }

  /// Updates element layout in-memory ONLY — no disk write.
  /// Call this on every drag frame for smooth 60 fps movement.
  /// Call [updateElement] once on gesture end to persist.
  void updateElementLive(String screenId, ElementLayout el) {
    final current = state.valueOrNull ?? {};
    final screen  = (current[screenId] ?? const ScreenLayout()).withElement(el);
    state = AsyncValue.data({...current, screenId: screen});
  }

  Future<void> resetElement(String screenId, String elementId) async {
    final current = state.valueOrNull ?? {};
    final screen  = (current[screenId] ?? const ScreenLayout()).withoutElement(elementId);
    await _prefs.setString(_key(screenId), screen.toJsonString());
    state = AsyncValue.data({...current, screenId: screen});
  }

  Future<void> resetLayout(String screenId) async {
    final current = state.valueOrNull ?? {};
    await _prefs.remove(_key(screenId));
    state = AsyncValue.data({...current, screenId: const ScreenLayout()});
  }
}

final layoutProvider =
    AsyncNotifierProvider<LayoutNotifier, Map<String, ScreenLayout>>(
  LayoutNotifier.new,
);

// Convenience selectors — rebuilds only when the relevant screen changes.
final racingLayoutProvider = Provider<ScreenLayout>((ref) =>
    ref.watch(layoutProvider).valueOrNull?['racing'] ?? const ScreenLayout());

final fpsLayoutProvider = Provider<ScreenLayout>((ref) =>
    ref.watch(layoutProvider).valueOrNull?['fps'] ?? const ScreenLayout());

// ─────────────────────────────────────────────────────────────────────────────
// Edit-mode flag — one per screen ('racing' | 'fps')
// ─────────────────────────────────────────────────────────────────────────────

final editModeProvider =
    StateProvider.family<bool, String>((ref, screenId) => false);

// ─────────────────────────────────────────────────────────────────────────────
// Selection — which element is currently selected per screen (null = none)
// ─────────────────────────────────────────────────────────────────────────────

final selectedElementProvider =
    StateProvider.family<String?, String>((ref, screenId) => null);
