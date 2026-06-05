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

/// A single beat event.
class BeatEvent {
  /// 0-based index of the beat within the bar.
  final int beatIndex;

  /// Whether this is the accent (first beat of the bar).
  final bool isAccent;

  /// Theoretical fire time of this beat (microseconds since engine start),
  /// used for precision measurement.
  final int scheduledMicros;

  const BeatEvent({
    required this.beatIndex,
    required this.isAccent,
    required this.scheduledMicros,
  });
}

/// Timing engine configuration. All fields are immutable; use [copyWith] to
/// produce a new instance with changes.
class MetronomeConfig {
  final int bpm;
  final int beatsPerBar;

  const MetronomeConfig({this.bpm = 120, this.beatsPerBar = 4});

  /// Duration of one beat in microseconds.
  int get beatIntervalMicros => (60 * 1000 * 1000) ~/ bpm;

  MetronomeConfig copyWith({int? bpm, int? beatsPerBar}) => MetronomeConfig(
        bpm: bpm ?? this.bpm,
        beatsPerBar: beatsPerBar ?? this.beatsPerBar,
      );
}

/// Abstract timing engine interface. The state layer depends only on this, so
/// implementations can be swapped between test and production.
abstract class MetronomeEngine {
  /// Beat callback. Can be replaced after construction.
  set onBeatHandler(void Function(BeatEvent event) handler);

  bool get isRunning;

  void start();
  void stop();

  /// Update configuration (BPM / time signature) while running.
  void updateConfig(MetronomeConfig config);

  void dispose();
}
