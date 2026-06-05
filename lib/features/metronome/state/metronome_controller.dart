/// Metronome state and control layer.
///
/// Glues together the timing engine, sound layer, and UI state. The UI talks
/// only to this layer. Uses ChangeNotifier instead of Riverpod: the MVP state
/// is simple, one less dependency, and easier to test.
library;

// The constructor intentionally uses named params + an initializer list
// (fields are private, and engine needs a fallback construction); this reads
// better than initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/audio/click_player.dart';
import '../../../core/timing/isolate_metronome_engine.dart';
import '../../../core/timing/metronome_engine.dart';
import '../../../data/settings_repository.dart';

/// Allowed BPM range.
const int kMinBpm = 30;
const int kMaxBpm = 300;

/// Common time signatures (beats per bar).
const List<int> kBeatsPerBarOptions = [2, 3, 4, 6];

class MetronomeController extends ChangeNotifier {
  final MetronomeEngine _engine;
  final ClickPlayer _player;
  final SettingsRepository _settings;

  int _bpm = 120;
  int _beatsPerBar = 4;
  bool _isPlaying = false;

  /// Currently highlighted beat (-1 means not playing).
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

  /// Called on startup: load audio + restore last settings.
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

  /// Set BPM (clamped to the allowed range) and persist it.
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
