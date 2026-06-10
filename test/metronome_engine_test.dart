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

    test('slotIntervalMicros is beatInterval / slotsPerBeat', () {
      expect(const MetronomeConfig(bpm: 120).slotIntervalMicros, 125000);
      expect(
        MetronomeConfig(
          bpm: 120,
          pattern: RhythmPattern(
            id: 'triplet', name: '三连音',
            slots: [SlotType.accent, SlotType.normal, SlotType.normal],
            glyph: 'T',
          ),
        ).slotIntervalMicros,
        500000 ~/ 3,
      );
    });

    test('copyWith returns a new instance without mutating the original', () {
      const a = MetronomeConfig(bpm: 120, beatsPerBar: 4);
      final b = a.copyWith(bpm: 90);
      expect(a.bpm, 120);
      expect(b.bpm, 90);
      expect(b.beatsPerBar, 4);
    });
  });

  group('MetronomeEngine beat logic (全拍 pattern)', () {
    // quarter pattern: only slot 0 of each beat fires, so event count == beat count.
    const quarterConfig = MetronomeConfig(bpm: 120, beatsPerBar: 4);

    test('accent falls on the first beat of each bar (slot 0)', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: quarterConfig,
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 2100)); // ~4 beats
        engine.stop();
      });

      expect(events.length, greaterThanOrEqualTo(4));
      expect(events[0].isAccent, isTrue);
      expect(events[0].slotIndex, 0);
      expect(events[1].isAccent, isFalse);
      expect(events[4].isAccent, isTrue); // 5th beat = bar downbeat again
      expect(events.map((e) => e.beatIndex).take(5).toList(), [0, 1, 2, 3, 0]);
    });

    test('no cumulative drift: slot intervals are exactly equal', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: quarterConfig,
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(seconds: 10)); // 120 BPM x 10s = 20 beats
        engine.stop();
      });

      // quarter pattern fires one slot per beat; intervals must be exactly 500ms.
      for (var i = 1; i < events.length; i++) {
        final delta = events[i].scheduledMicros - events[i - 1].scheduledMicros;
        expect(delta, 500000,
            reason: 'beat $i interval should be 500ms, got $delta us');
      }
      expect(events[19].scheduledMicros, 19 * 500000);
    });

    test('changing BPM while running affects subsequent intervals', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: quarterConfig,
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 1100)); // ~2 beats @120
        engine.updateConfig(const MetronomeConfig(bpm: 60));
        async.elapse(const Duration(milliseconds: 2100)); // ~2 beats @60
        engine.stop();
      });

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

  group('MetronomeEngine beat logic (十六分 pattern)', () {
    const sixteenthConfig = MetronomeConfig(
      bpm: 120,
      beatsPerBar: 4,
      pattern: RhythmPattern(
        id: 'sixteenth',
        name: '十六分',
        slots: [SlotType.accent, SlotType.normal, SlotType.normal, SlotType.normal],
        glyph: 'y',
      ),
    );

    test('fires 4 slots per beat, slot intervals are 125ms each', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: sixteenthConfig,
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 510)); // ~1 beat = 4 slots
        engine.stop();
      });

      expect(events.length, greaterThanOrEqualTo(4));
      // First event: bar accent
      expect(events[0].slotType, SlotType.accent);
      expect(events[0].slotIndex, 0);
      // Second through fourth slots are normal
      expect(events[1].slotType, SlotType.normal);
      expect(events[1].slotIndex, 1);
      // Slot intervals are 125ms
      final delta = events[1].scheduledMicros - events[0].scheduledMicros;
      expect(delta, 125000);
    });
  });

  group('MetronomeEngine beat logic (全休止 pattern)', () {
    const muteConfig = MetronomeConfig(
      bpm: 120,
      beatsPerBar: 4,
      pattern: RhythmPattern(
        id: 'mute',
        name: '全休止',
        slots: [SlotType.rest, SlotType.rest, SlotType.rest, SlotType.rest],
        glyph: 'Q',
      ),
    );

    test('only slot-0 beat-position events fired for mute pattern (no audio slots)', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: muteConfig,
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 2100));
        engine.stop();
      });

      // Slot-0 events fire so the beat bar advances even for all-rest patterns.
      expect(events, isNotEmpty);
      expect(events.every((e) => e.slotIndex == 0), isTrue);
      expect(events.every((e) => e.slotType == SlotType.rest), isTrue);
    });
  });

  group('MetronomeEngine beat logic (三连音 pattern)', () {
    const tripletConfig = MetronomeConfig(
      bpm: 120,
      beatsPerBar: 4,
      pattern: RhythmPattern(
        id: 'triplet',
        name: '三连音',
        slots: [SlotType.accent, SlotType.normal, SlotType.normal],
        glyph: 'T',
      ),
    );

    test('fires 3 slots per beat with equal spacing', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: tripletConfig,
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 510)); // ~1 beat = 3 slots
        engine.stop();
      });

      expect(events.length, greaterThanOrEqualTo(3));
      expect(events[0].slotType, SlotType.accent);
      expect(events[1].slotType, SlotType.normal);
      expect(events[1].slotIndex, 1);
      expect(events[2].slotIndex, 2);
      // Each triplet slot = 500000µs / 3 = 166666µs (beat-anchored, no drift)
      expect(events[1].scheduledMicros - events[0].scheduledMicros, 500000 ~/ 3);
      expect(events[2].scheduledMicros - events[0].scheduledMicros, 2 * 500000 ~/ 3);
    });

    test('beat boundaries are exact — no sub-microsecond drift across 10s', () {
      // With beat-anchored scheduling each beat slot[0] lands at exactly
      // N * beatIntervalMicros regardless of slotsPerBeat.
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: tripletConfig,
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(seconds: 10)); // 20 beats
        engine.stop();
      });

      final beatSlot0 = events.where((e) => e.slotIndex == 0).toList();
      for (var i = 0; i < beatSlot0.length; i++) {
        expect(beatSlot0[i].scheduledMicros, i * 500000,
            reason: 'beat $i slot 0 should be at ${i * 500000}µs');
      }
    });
  });
}
