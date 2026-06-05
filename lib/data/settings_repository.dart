/// Persistence for metronome settings.
///
/// Uses shared_preferences to store the last BPM and time signature, restored
/// on next launch.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Immutable settings snapshot.
class MetronomeSettings {
  final int bpm;
  final int beatsPerBar;

  const MetronomeSettings({required this.bpm, required this.beatsPerBar});

  static const MetronomeSettings defaults =
      MetronomeSettings(bpm: 120, beatsPerBar: 4);
}

/// Settings repository interface; allows injecting a fake in tests.
abstract class SettingsRepository {
  Future<MetronomeSettings> load();
  Future<void> save(MetronomeSettings settings);
}

/// shared_preferences-based implementation.
class PrefsSettingsRepository implements SettingsRepository {
  static const _kBpm = 'metronome.bpm';
  static const _kBeatsPerBar = 'metronome.beatsPerBar';

  @override
  Future<MetronomeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MetronomeSettings(
      bpm: prefs.getInt(_kBpm) ?? MetronomeSettings.defaults.bpm,
      beatsPerBar:
          prefs.getInt(_kBeatsPerBar) ?? MetronomeSettings.defaults.beatsPerBar,
    );
  }

  @override
  Future<void> save(MetronomeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBpm, settings.bpm);
    await prefs.setInt(_kBeatsPerBar, settings.beatsPerBar);
  }
}
