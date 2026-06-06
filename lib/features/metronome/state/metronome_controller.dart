/// Metronome state and control layer.
library;

// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/audio/click_player.dart';
import '../../../core/audio/timbre.dart';
import '../../../core/timing/isolate_metronome_engine.dart';
import '../../../core/timing/metronome_engine.dart';
import '../../../data/settings_repository.dart';

const int kMinBpm = 30;
const int kMaxBpm = 300;
const List<int> kBeatsPerBarOptions = [2, 3, 4, 6];

class MetronomeController extends ChangeNotifier {
  final MetronomeEngine _engine;
  final ClickPlayer _player;
  final SettingsRepository _settings;

  int _bpm = 120;
  int _beatsPerBar = 4;
  RhythmPattern _pattern = kRhythmPresets.first;
  Timbre _timbre = kDefaultTimbre;
  bool _isPlaying = false;
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
  RhythmPattern get pattern => _pattern;
  Timbre get timbre => _timbre;
  bool get isPlaying => _isPlaying;
  int get currentBeat => _currentBeat;

  Future<void> init() async {
    await _player.init();
    final saved = await _settings.load();
    _bpm = saved.bpm.clamp(kMinBpm, kMaxBpm);
    _beatsPerBar = saved.beatsPerBar;
    _pattern = patternById(saved.patternId);
    _timbre = timbreById(saved.timbreId);
    _player.setTimbre(_timbre);
    _engine.updateConfig(
      MetronomeConfig(bpm: _bpm, beatsPerBar: _beatsPerBar, pattern: _pattern),
    );
    notifyListeners();
  }

  void _handleBeat(BeatEvent event) {
    switch (event.slotType) {
      case SlotType.accent:
        _player.playAccent();
      case SlotType.normal:
        _player.playNormal();
      case SlotType.rest:
        break;
    }
    // Only update the beat indicator on slot 0 of each beat.
    if (event.slotIndex == 0) {
      _currentBeat = event.beatIndex;
      notifyListeners();
    }
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

  void setBpm(int value) {
    final clamped = value.clamp(kMinBpm, kMaxBpm);
    if (clamped == _bpm) return;
    _bpm = clamped;
    _pushConfig();
    _save();
    notifyListeners();
  }

  void nudgeBpm(int delta) => setBpm(_bpm + delta);

  void setBeatsPerBar(int value) {
    if (value == _beatsPerBar) return;
    _beatsPerBar = value;
    _pushConfig();
    _save();
    notifyListeners();
  }

  void setPattern(RhythmPattern p) {
    if (p.id == _pattern.id) return;
    _pattern = p;
    _pushConfig();
    _save();
    notifyListeners();
  }

  void setTimbre(Timbre t) {
    if (t.id == _timbre.id) return;
    _timbre = t;
    _player.setTimbre(t);
    _save();
    notifyListeners();
  }

  void _pushConfig() =>
      _engine.updateConfig(MetronomeConfig(bpm: _bpm, beatsPerBar: _beatsPerBar, pattern: _pattern));

  void _save() => _settings.save(MetronomeSettings(
        bpm: _bpm,
        beatsPerBar: _beatsPerBar,
        patternId: _pattern.id,
        timbreId: _timbre.id,
      ));

  @override
  void dispose() {
    _engine.dispose();
    _player.dispose();
    super.dispose();
  }
}
