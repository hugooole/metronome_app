/// 节拍器设置的持久化。
///
/// 用 shared_preferences 存最近一次的 BPM 和拍号，下次启动恢复。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// 不可变的设置快照。
class MetronomeSettings {
  final int bpm;
  final int beatsPerBar;

  const MetronomeSettings({required this.bpm, required this.beatsPerBar});

  static const MetronomeSettings defaults =
      MetronomeSettings(bpm: 120, beatsPerBar: 4);
}

/// 设置仓库接口，便于测试注入假实现。
abstract class SettingsRepository {
  Future<MetronomeSettings> load();
  Future<void> save(MetronomeSettings settings);
}

/// 基于 shared_preferences 的实现。
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
