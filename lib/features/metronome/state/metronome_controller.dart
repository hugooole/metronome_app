/// 节拍器状态与控制层。
///
/// 把计时引擎、发声层、UI 状态粘合起来。UI 只跟这一层打交道。
/// 用 ChangeNotifier 而非 Riverpod：MVP 状态简单，少一层依赖，更易测。
library;

// 构造函数有意用命名参数 + 初始化列表（字段私有，engine 需回退构造），可读性更好。
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/audio/click_player.dart';
import '../../../core/timing/isolate_metronome_engine.dart';
import '../../../core/timing/metronome_engine.dart';
import '../../../data/settings_repository.dart';

/// BPM 允许范围。
const int kMinBpm = 30;
const int kMaxBpm = 300;

/// 常用拍号（每小节拍数）。
const List<int> kBeatsPerBarOptions = [2, 3, 4, 6];

class MetronomeController extends ChangeNotifier {
  final MetronomeEngine _engine;
  final ClickPlayer _player;
  final SettingsRepository _settings;

  int _bpm = 120;
  int _beatsPerBar = 4;
  bool _isPlaying = false;

  /// 当前高亮的拍（-1 表示未播放）。
  int _currentBeat = -1;

  MetronomeController({
    required ClickPlayer player,
    required SettingsRepository settings,
    MetronomeEngine? engine,
  })  : _player = player,
        _settings = settings,
        _engine = engine ?? IsolateMetronomeEngine(onBeat: (_) {}) {
    _engine.onBeatHandler = _handleBeat;
  }

  int get bpm => _bpm;
  int get beatsPerBar => _beatsPerBar;
  bool get isPlaying => _isPlaying;
  int get currentBeat => _currentBeat;

  /// 启动时调用：加载音频 + 恢复上次设置。
  Future<void> init() async {
    await _player.init();
    final saved = await _settings.load();
    _bpm = saved.bpm.clamp(kMinBpm, kMaxBpm);
    _beatsPerBar = saved.beatsPerBar;
    _engine.updateConfig(
      MetronomeConfig(bpm: _bpm, beatsPerBar: _beatsPerBar),
    );
    notifyListeners();
  }

  void _handleBeat(BeatEvent event) {
    if (event.isAccent) {
      _player.playAccent();
    } else {
      _player.playNormal();
    }
    _currentBeat = event.beatIndex;
    notifyListeners();
  }

  void toggle() => _isPlaying ? stop() : start();

  void start() {
    if (_isPlaying) return;
    _isPlaying = true;
    _currentBeat = -1;
    _engine.start();
    notifyListeners();
  }

  void stop() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _currentBeat = -1;
    _engine.stop();
    notifyListeners();
  }

  /// 设置 BPM（自动夹到合法范围），持久化。
  void setBpm(int value) {
    final clamped = value.clamp(kMinBpm, kMaxBpm);
    if (clamped == _bpm) return;
    _bpm = clamped;
    _engine.updateConfig(MetronomeConfig(bpm: _bpm, beatsPerBar: _beatsPerBar));
    _settings.save(MetronomeSettings(bpm: _bpm, beatsPerBar: _beatsPerBar));
    notifyListeners();
  }

  void nudgeBpm(int delta) => setBpm(_bpm + delta);

  void setBeatsPerBar(int value) {
    if (value == _beatsPerBar) return;
    _beatsPerBar = value;
    _engine.updateConfig(MetronomeConfig(bpm: _bpm, beatsPerBar: _beatsPerBar));
    _settings.save(MetronomeSettings(bpm: _bpm, beatsPerBar: _beatsPerBar));
    notifyListeners();
  }

  @override
  void dispose() {
    _engine.dispose();
    _player.dispose();
    super.dispose();
  }
}
