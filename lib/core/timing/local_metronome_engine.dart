/// Same-isolate timing engine implementation.
///
/// Uses `package:clock`'s injectable clock (instead of Stopwatch) so fakeAsync
/// can take over time, enabling precise unit tests of the drift-free schedule.
/// Production uses [IsolateMetronomeEngine].
library;

// The constructor intentionally uses named params + an initializer list
// (fields are private); this reads better than initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:clock/clock.dart';

import 'metronome_engine.dart';

class LocalMetronomeEngine implements MetronomeEngine {
  /// Check interval. Much smaller than the beat interval so the "is it time
  /// yet" decision is timely enough.
  static const Duration _tickInterval = Duration(milliseconds: 5);

  void Function(BeatEvent event) _onBeat;
  MetronomeConfig _config;

  Timer? _ticker;
  DateTime? _startTime;
  int _nextBeatMicros = 0;
  int _nextBeatIndex = 0;

  LocalMetronomeEngine({
    required void Function(BeatEvent event) onBeat,
    MetronomeConfig config = const MetronomeConfig(),
  })  : _onBeat = onBeat,
        _config = config;

  @override
  set onBeatHandler(void Function(BeatEvent event) handler) =>
      _onBeat = handler;

  @override
  bool get isRunning => _ticker != null;

  @override
  void start() {
    if (isRunning) return;
    _startTime = clock.now();
    _nextBeatMicros = 0; // first beat fires immediately
    _nextBeatIndex = 0;
    _ticker = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  @override
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _startTime = null;
  }

  @override
  void updateConfig(MetronomeConfig next) {
    _config = next;
    if (_nextBeatIndex >= next.beatsPerBar) {
      _nextBeatIndex = 0;
    }
  }

  void _onTick() {
    final startTime = _startTime;
    if (startTime == null) return;

    final now = clock.now().difference(startTime).inMicroseconds;

    // A single tick may need to emit multiple beats (very high BPM or a
    // main-thread stall).
    while (now >= _nextBeatMicros) {
      final beatIndex = _nextBeatIndex;
      _onBeat(BeatEvent(
        beatIndex: beatIndex,
        isAccent: beatIndex == 0,
        scheduledMicros: _nextBeatMicros,
      ));
      // Theoretical time advances by the beat interval — drift eliminated here.
      _nextBeatMicros += _config.beatIntervalMicros;
      _nextBeatIndex = (beatIndex + 1) % _config.beatsPerBar;
    }
  }

  @override
  void dispose() => stop();
}
