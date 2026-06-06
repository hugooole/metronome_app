import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/timing/isolate_metronome_engine.dart';
import 'package:metronome_app/core/timing/metronome_engine.dart';

void main() {
  test('IsolateMetronomeEngine sends beats with accent first (全拍 pattern)',
      () async {
    final events = <BeatEvent>[];
    final engine = IsolateMetronomeEngine(
      onBeat: events.add,
      config: const MetronomeConfig(bpm: 240, beatsPerBar: 4),
    );

    engine.start();
    await Future.delayed(const Duration(milliseconds: 1200));
    engine.stop();

    expect(events.length, greaterThanOrEqualTo(3));
    expect(events.first.beatIndex, 0);
    expect(events.first.isAccent, isTrue);

    // Bar cycle: beat indices 0,1,2,3
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
