/// Metronome timing engine — shared types and abstract interface.
///
/// Core design: self-correcting scheduling that eliminates cumulative drift.
///   Keeps a "theoretical beat time" that advances by `+= interval`, rather
///   than resetting the baseline to the actual fire time. Even if a check is a
///   few milliseconds late, the next beat's theoretical time is unaffected, so
///   error does not accumulate.
///
/// Two implementations:
///   - [LocalMetronomeEngine]: same-isolate, uses an injectable clock for
///     precise fakeAsync testing.
///   - [IsolateMetronomeEngine]: dedicated Isolate so main-thread stalls don't
///     affect the beat; used in production.
library;

import 'rhythm_pattern.dart';
export 'rhythm_pattern.dart';

/// A single subdivision slot event.
class BeatEvent {
  /// 0-based index of the beat within the bar.
  final int beatIndex;

  /// 0-based slot index within the beat. The slot count is the pattern's
  /// `slots.length` — 4 for sixteenth subdivision, 3 for triplets.
  final int slotIndex;

  /// Sound type for this slot.
  final SlotType slotType;

  /// Whether this is the bar accent (beat 0, slot 0, non-rest).
  bool get isAccent => slotType == SlotType.accent;

  /// Theoretical fire time of this slot (microseconds since engine start).
  final int scheduledMicros;

  const BeatEvent({
    required this.beatIndex,
    required this.slotIndex,
    required this.slotType,
    required this.scheduledMicros,
  });
}

/// Timing engine configuration. All fields are immutable; use [copyWith] to
/// produce a new instance with changes.
class MetronomeConfig {
  final int bpm;
  final int beatsPerBar;
  final RhythmPattern pattern;

  const MetronomeConfig({
    this.bpm = 120,
    this.beatsPerBar = 4,
    this.pattern = kDefaultPattern,
  });

  /// Duration of one beat in microseconds.
  int get beatIntervalMicros => (60 * 1000 * 1000) ~/ bpm;

  /// Number of subdivision slots per beat (4 for sixteenths, 3 for triplets).
  int get slotsPerBeat => pattern.slots.length;

  /// Nominal duration of one subdivision slot in microseconds.
  ///
  /// Used only for display/approximation; the engines anchor each slot to the
  /// beat boundary instead of summing this value, so a beat that does not
  /// divide evenly (e.g. triplets) accumulates no drift.
  int get slotIntervalMicros => beatIntervalMicros ~/ slotsPerBeat;

  MetronomeConfig copyWith({
    int? bpm,
    int? beatsPerBar,
    RhythmPattern? pattern,
  }) =>
      MetronomeConfig(
        bpm: bpm ?? this.bpm,
        beatsPerBar: beatsPerBar ?? this.beatsPerBar,
        pattern: pattern ?? this.pattern,
      );
}

/// Abstract timing engine interface. The state layer depends only on this, so
/// implementations can be swapped between test and production.
abstract class MetronomeEngine {
  /// Beat callback. Can be replaced after construction.
  set onBeatHandler(void Function(BeatEvent event) handler);

  bool get isRunning;

  /// True when the engine handles audio playback natively. When true,
  /// MetronomeController skips ClickPlayer calls on beat events.
  bool get handlesAudio => false;

  void start();
  void stop();

  /// Update configuration (BPM / time signature / pattern) while running.
  void updateConfig(MetronomeConfig config);

  void dispose();
}
