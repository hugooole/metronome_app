import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/timing/isolate_metronome_engine.dart';
import 'package:metronome_app/core/timing/metronome_engine.dart';

void main() {
  // The Isolate engine uses a real clock and can't be fakeAsync'd, so use real
  // delays for integration verification.
  test('IsolateMetronomeEngine running for real sends beats with accent first',
      () async {
    final events = <BeatEvent>[];
    final engine = IsolateMetronomeEngine(
      onBeat: events.add,
      config: const MetronomeConfig(bpm: 240, beatsPerBar: 4), // 250ms/beat
    );

    engine.start();
    // Wait ~1.1s; at 240 BPM there should be 4~5 beats. Leave room for Isolate
    // startup.
    await Future.delayed(const Duration(milliseconds: 1200));
    engine.stop();

    expect(events.length, greaterThanOrEqualTo(3),
        reason: 'should receive multiple beats via SendPort');
    expect(events.first.beatIndex, 0);
    expect(events.first.isAccent, isTrue);

    // Verify the bar cycle is correct.
    final indices = events.map((e) => e.beatIndex).take(4).toList();
    expect(indices, [0, 1, 2, 3]);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('no beats sent after stop', () async {
    final events = <BeatEvent>[];
    final engine = IsolateMetronomeEngine(
      onBeat: events.add,
      config: const MetronomeConfig(bpm: 240),
    );
    engine.start();
    await Future.delayed(const Duration(milliseconds: 600));
    engine.stop();
    final countAtStop = events.length;
    await Future.delayed(const Duration(milliseconds: 600));
    expect(events.length, countAtStop);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
