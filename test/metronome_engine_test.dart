import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/timing/local_metronome_engine.dart';
import 'package:metronome_app/core/timing/metronome_engine.dart';

void main() {
  group('MetronomeConfig', () {
    test('beatIntervalMicros converts from BPM correctly', () {
      expect(const MetronomeConfig(bpm: 60).beatIntervalMicros, 1000000);
      expect(const MetronomeConfig(bpm: 120).beatIntervalMicros, 500000);
      expect(const MetronomeConfig(bpm: 240).beatIntervalMicros, 250000);
    });

    test('copyWith returns a new instance without mutating the original', () {
      const a = MetronomeConfig(bpm: 120, beatsPerBar: 4);
      final b = a.copyWith(bpm: 90);
      expect(a.bpm, 120); // original unchanged
      expect(b.bpm, 90);
      expect(b.beatsPerBar, 4); // unchanged field carried over
    });
  });

  group('MetronomeEngine beat logic', () {
    test('accent falls on the first beat of each bar', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: const MetronomeConfig(bpm: 120, beatsPerBar: 4),
      );
      addTearDown(engine.dispose);

      // Advance the clock under fakeAsync to drive the internal logic and make
      // pure-logic assertions on the beat sequence.
      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 2100)); // a bit over 4 beats
        engine.stop();
      });

      expect(events.length, greaterThanOrEqualTo(4));
      expect(events[0].isAccent, isTrue); // beat 1 is the accent
      expect(events[1].isAccent, isFalse);
      expect(events[4].isAccent, isTrue); // beat 5 = first beat of next bar
      expect(events.map((e) => e.beatIndex).take(5).toList(),
          [0, 1, 2, 3, 0]);
    });

    test('no cumulative drift: theoretical beat times are exactly equal',
        () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: const MetronomeConfig(bpm: 120),
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(seconds: 10)); // 120 BPM x 10s ~= 20 beats
        engine.stop();
      });

      // Adjacent theoretical intervals must be exactly 500000us — zero drift.
      for (var i = 1; i < events.length; i++) {
        final delta =
            events[i].scheduledMicros - events[i - 1].scheduledMicros;
        expect(delta, 500000,
            reason: 'beat $i interval should be 500ms, got $delta us');
      }
      // The 20th beat's accumulated time = 19 x 500ms, never offset by jitter.
      expect(events[19].scheduledMicros, 19 * 500000);
    });

    test('changing BPM while running affects subsequent intervals', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: const MetronomeConfig(bpm: 120),
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 1100)); // ~3 beats @120
        engine.updateConfig(const MetronomeConfig(bpm: 60));
        async.elapse(const Duration(milliseconds: 2100)); // ~2 beats @60
        engine.stop();
      });

      // A 1000ms interval appears after the tempo change.
      final deltas = <int>[];
      for (var i = 1; i < events.length; i++) {
        deltas.add(events[i].scheduledMicros - events[i - 1].scheduledMicros);
      }
      expect(deltas, contains(1000000));
    });

    test('no beats emitted after stop', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(onBeat: events.add);
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 600));
        final countAtStop = events.length;
        engine.stop();
        async.elapse(const Duration(seconds: 2));
        expect(events.length, countAtStop);
      });
    });
  });
}
