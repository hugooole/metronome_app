/// Persistence for metronome settings.
library;

import 'package:shared_preferences/shared_preferences.dart';

class MetronomeSettings {
  final int bpm;
  final int beatsPerBar;
  final String patternId;
  final String timbreId;

  const MetronomeSettings({
    required this.bpm,
    required this.beatsPerBar,
    this.patternId = 'quarter',
    this.timbreId = 'click',
  });

  static const MetronomeSettings defaults =
      MetronomeSettings(bpm: 120, beatsPerBar: 4);
}

abstract class SettingsRepository {
  Future<MetronomeSettings> load();
  Future<void> save(MetronomeSettings settings);
}

class PrefsSettingsRepository implements SettingsRepository {
  static const _kBpm = 'metronome.bpm';
  static const _kBeatsPerBar = 'metronome.beatsPerBar';
  static const _kPatternId = 'metronome.patternId';
  static const _kTimbreId = 'metronome.timbreId';

  @override
  Future<MetronomeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MetronomeSettings(
      bpm: prefs.getInt(_kBpm) ?? MetronomeSettings.defaults.bpm,
      beatsPerBar: prefs.getInt(_kBeatsPerBar) ?? MetronomeSettings.defaults.beatsPerBar,
      patternId: prefs.getString(_kPatternId) ?? MetronomeSettings.defaults.patternId,
      timbreId: prefs.getString(_kTimbreId) ?? MetronomeSettings.defaults.timbreId,
    );
  }

  @override
  Future<void> save(MetronomeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBpm, settings.bpm);
    await prefs.setInt(_kBeatsPerBar, settings.beatsPerBar);
    await prefs.setString(_kPatternId, settings.patternId);
    await prefs.setString(_kTimbreId, settings.timbreId);
  }
}
