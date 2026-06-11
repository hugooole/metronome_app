import 'package:flutter/foundation.dart';

import '../../../core/audio/click_player.dart';
import '../../../core/audio/timbre.dart';
import '../../../core/timing/local_metronome_engine.dart';
import '../../../core/timing/metronome_engine.dart';
import '../../../core/timing/native_metronome_engine.dart';
import '../../../data/settings_repository.dart';
import '../models/practice_grid.dart';

const int kMinBpm = 30;
const int kMaxBpm = 300;

class PracticeController extends ChangeNotifier {
  final MetronomeEngine _engine;
  final ClickPlayer _player;
  final SettingsRepository _settings;

  int _bpm = 120;
  Timbre _timbre = kDefaultTimbre;
  bool _isPlaying = false;
  bool _showCues = true;

  PracticeGrid _grid = PracticeGrid.initial();
  int _currentBeat = -1;

  PracticeController({
    required ClickPlayer player,
    required SettingsRepository settings,
    MetronomeEngine? engine,
  })  : _player = player,
        _settings = settings,
        _engine = engine ??
            (kIsWeb
                ? LocalMetronomeEngine(onBeat: (_) {})
                : NativeMetronomeEngine(onBeat: (_) {})) {
    _engine.onBeatHandler = _handleBeat;
  }

  int get bpm => _bpm;
  Timbre get timbre => _timbre;
  bool get isPlaying => _isPlaying;
  bool get showCues => _showCues;
  PracticeGrid get grid => _grid;
  int get currentBeat => _currentBeat;

  Future<void> init() async {
    notifyListeners();
  }

  void updateColumnPattern(int columnIndex, int patternIndex) {
    _grid = _grid.updateColumn(columnIndex, patternIndex);
    notifyListeners();
  }

  void setBpm(int value) {
    final clamped = value.clamp(kMinBpm, kMaxBpm);
    if (_bpm == clamped) return;
    _bpm = clamped;

    if (_isPlaying) {
      _updateEngineConfig();
    }
    notifyListeners();
  }

  void setTimbre(Timbre t) {
    if (_timbre == t) return;
    _timbre = t;
    _player.setTimbre(t);
    notifyListeners();
  }

  void toggleCues() {
    _showCues = !_showCues;
    notifyListeners();
  }

  void start() {
    if (_isPlaying) return;

    _isPlaying = true;
    _currentBeat = -1;
    _grid = _grid.copyWith(currentBeat: -1);
    _updateEngineConfig();
    _engine.start();
    notifyListeners();
  }

  void stop() {
    if (!_isPlaying) return;
    _isPlaying = false;
    _currentBeat = -1;
    _grid = _grid.copyWith(currentBeat: -1);
    _engine.stop();
    notifyListeners();
  }

  void toggle() {
    if (_isPlaying) {
      stop();
    } else {
      start();
    }
  }

  void _updateEngineConfig() {
    final currentPattern = _grid.patternForBeat(
      _currentBeat >= 0 ? _currentBeat : 0,
    );
    _engine.updateConfig(MetronomeConfig(
      bpm: _bpm,
      beatsPerBar: 4,
      pattern: currentPattern,
    ));
  }

  void _handleBeat(BeatEvent event) {
    if (!_isPlaying) return;

    _currentBeat = event.beatIndex;
    _grid = _grid.copyWith(currentBeat: event.beatIndex);

    // Update engine config for the next beat's pattern
    final nextBeat = (event.beatIndex + 1) % 4;
    final isLastSlot = event.slotIndex == _grid.patternForBeat(event.beatIndex).slots.length - 1;
    final isLastBeatOfBar = event.beatIndex == 3;

    if (isLastSlot && isLastBeatOfBar) {
      // About to loop back to beat 0, update pattern
      _updateEngineConfig();
    } else if (isLastSlot) {
      // About to move to next beat, update pattern
      final nextPattern = _grid.patternForBeat(nextBeat);
      _engine.updateConfig(MetronomeConfig(
        bpm: _bpm,
        beatsPerBar: 4,
        pattern: nextPattern,
      ));
    }

    if (_showCues && event.slotType != SlotType.rest) {
      if (event.slotType == SlotType.accent) {
        _player.playAccent();
      } else {
        _player.playNormal();
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
