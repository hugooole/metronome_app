import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/timing/local_metronome_engine.dart';
import 'package:metronome_app/core/timing/metronome_engine.dart';

void main() {
  group('MetronomeConfig', () {
    test('beatIntervalMicros 按 BPM 正确换算', () {
      expect(const MetronomeConfig(bpm: 60).beatIntervalMicros, 1000000);
      expect(const MetronomeConfig(bpm: 120).beatIntervalMicros, 500000);
      expect(const MetronomeConfig(bpm: 240).beatIntervalMicros, 250000);
    });

    test('copyWith 返回新实例且不改原值（不可变）', () {
      const a = MetronomeConfig(bpm: 120, beatsPerBar: 4);
      final b = a.copyWith(bpm: 90);
      expect(a.bpm, 120); // 原值不变
      expect(b.bpm, 90);
      expect(b.beatsPerBar, 4); // 未改字段沿用
    });
  });

  group('MetronomeEngine 拍点逻辑', () {
    test('强拍落在每小节第一拍', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: const MetronomeConfig(bpm: 120, beatsPerBar: 4),
      );
      addTearDown(engine.dispose);

      // 手动模拟时钟推进，直接驱动内部逻辑做纯逻辑断言。
      // 这里用真实计时在 fakeAsync 下验证序列。
      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 2100)); // 约 4 拍多
        engine.stop();
      });

      expect(events.length, greaterThanOrEqualTo(4));
      expect(events[0].isAccent, isTrue); // 第 1 拍强
      expect(events[1].isAccent, isFalse);
      expect(events[4].isAccent, isTrue); // 第 5 拍 = 下小节第 1 拍
      expect(events.map((e) => e.beatIndex).take(5).toList(),
          [0, 1, 2, 3, 0]);
    });

    test('计时无累积漂移：理论拍点时间严格等间隔', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: const MetronomeConfig(bpm: 120),
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(seconds: 10)); // 120 BPM × 10s ≈ 20 拍
        engine.stop();
      });

      // 相邻理论拍点间隔必须恒等于 500000µs，零漂移。
      for (var i = 1; i < events.length; i++) {
        final delta =
            events[i].scheduledMicros - events[i - 1].scheduledMicros;
        expect(delta, 500000,
            reason: '第 $i 拍间隔应为 500ms，实际 $delta µs');
      }
      // 第 20 拍的累积时间 = 19 × 500ms，绝不因抖动偏移。
      expect(events[19].scheduledMicros, 19 * 500000);
    });

    test('运行中改 BPM 影响后续拍间隔', () {
      final events = <BeatEvent>[];
      final engine = LocalMetronomeEngine(
        onBeat: events.add,
        config: const MetronomeConfig(bpm: 120),
      );
      addTearDown(engine.dispose);

      fakeAsync((async) {
        engine.start();
        async.elapse(const Duration(milliseconds: 1100)); // ~3 拍 @120
        engine.updateConfig(const MetronomeConfig(bpm: 60));
        async.elapse(const Duration(milliseconds: 2100)); // ~2 拍 @60
        engine.stop();
      });

      // 改速后出现 1000ms 间隔。
      final deltas = <int>[];
      for (var i = 1; i < events.length; i++) {
        deltas.add(events[i].scheduledMicros - events[i - 1].scheduledMicros);
      }
      expect(deltas, contains(1000000));
    });

    test('stop 后不再发拍', () {
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
