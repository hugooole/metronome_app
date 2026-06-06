/// Same-isolate timing engine implementation.
///
/// Uses `package:clock`'s injectable clock (instead of Stopwatch) so fakeAsync
/// can take over time, enabling precise unit tests of the drift-free schedule.
/// Production uses [IsolateMetronomeEngine].
library;

// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:clock/clock.dart';

import 'metronome_engine.dart';

class LocalMetronomeEngine implements MetronomeEngine {
  static const Duration _tickInterval = Duration(milliseconds: 5);

  void Function(BeatEvent event) _onBeat;
  MetronomeConfig _config;

  Timer? _ticker;
  DateTime? _startTime;
  // Beat-anchored scheduling: each beat's start is exact; slots within a beat
  // are derived as beatStart + slotIndex * beatInterval / slotsPerBeat.
  // This prevents fractional-microsecond drift accumulation for triplets.
  int _beatStartMicros = 0; // theoretical start of the current beat
  int _nextBeatIndex = 0;
  int _nextSlotIndex = 0; // 0 .. slotsPerBeat-1

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
    _beatStartMicros = 0;
    _nextBeatIndex = 0;
    _nextSlotIndex = 0;
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
    if (_nextBeatIndex >= next.beatsPerBar) _nextBeatIndex = 0;
  }

  int get _nextSlotMicros {
    final beat = _config.beatIntervalMicros;
    final n = _config.slotsPerBeat;
    return _beatStartMicros + _nextSlotIndex * beat ~/ n;
  }

  void _onTick() {
    final startTime = _startTime;
    if (startTime == null) return;

    final now = clock.now().difference(startTime).inMicroseconds;

    while (now >= _nextSlotMicros) {
      final beatIndex = _nextBeatIndex;
      final slotIndex = _nextSlotIndex;
      final scheduledMicros = _nextSlotMicros;
      final raw = _config.pattern.slots[slotIndex];
      // Bar downbeat (beat 0, slot 0): force accent unless the pattern rests it.
      // All other slots: treat pattern's `accent` marker as `normal`.
      final slotType = (beatIndex == 0 && slotIndex == 0)
          ? (raw == SlotType.rest ? SlotType.rest : SlotType.accent)
          : (raw == SlotType.accent ? SlotType.normal : raw);

      if (slotType != SlotType.rest) {
        _onBeat(BeatEvent(
          beatIndex: beatIndex,
          slotIndex: slotIndex,
          slotType: slotType,
          scheduledMicros: scheduledMicros,
        ));
      }

      _nextSlotIndex++;
      if (_nextSlotIndex >= _config.slotsPerBeat) {
        _nextSlotIndex = 0;
        // Beat boundary advances by exactly beatIntervalMicros — zero drift.
        _beatStartMicros += _config.beatIntervalMicros;
        _nextBeatIndex = (_nextBeatIndex + 1) % _config.beatsPerBar;
      }
    }
  }

  @override
  void dispose() => stop();
}
