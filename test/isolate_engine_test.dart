import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/timing/isolate_metronome_engine.dart';
import 'package:metronome_app/core/timing/metronome_engine.dart';

void main() {
  // Isolate 引擎用真实时钟，无法 fakeAsync，故用真实延时做集成验证。
  test('IsolateMetronomeEngine 真实运行能回传拍点且强拍在首拍', () async {
    final events = <BeatEvent>[];
    final engine = IsolateMetronomeEngine(
      onBeat: events.add,
      config: const MetronomeConfig(bpm: 240, beatsPerBar: 4), // 250ms/拍
    );

    engine.start();
    // 等约 1.1s，240 BPM 下应有 4~5 拍。给 Isolate 启动留余量。
    await Future.delayed(const Duration(milliseconds: 1200));
    engine.stop();

    expect(events.length, greaterThanOrEqualTo(3),
        reason: '应通过 SendPort 收到多个拍点');
    expect(events.first.beatIndex, 0);
    expect(events.first.isAccent, isTrue);

    // 验证拍号循环正确。
    final indices = events.map((e) => e.beatIndex).take(4).toList();
    expect(indices, [0, 1, 2, 3]);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('stop 后不再回传拍点', () async {
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
