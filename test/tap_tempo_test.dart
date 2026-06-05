import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/features/metronome/state/tap_tempo.dart';

void main() {
  group('TapTempoCalculator', () {
    test('不足两次敲击返回 null', () {
      final calc = TapTempoCalculator();
      expect(calc.tap(DateTime(2026)), isNull);
    });

    test('等间隔 500ms 敲击算出 120 BPM', () {
      final calc = TapTempoCalculator();
      final t0 = DateTime(2026, 1, 1, 0, 0, 0);
      calc.tap(t0);
      final bpm = calc.tap(t0.add(const Duration(milliseconds: 500)));
      expect(bpm, 120);
    });

    test('多次敲击取平均，结果稳定', () {
      final calc = TapTempoCalculator();
      var t = DateTime(2026);
      int? bpm;
      for (var i = 0; i < 5; i++) {
        bpm = calc.tap(t);
        t = t.add(const Duration(milliseconds: 600)); // 100 BPM
      }
      expect(bpm, 100);
    });

    test('超过 resetGap 重新开始计算', () {
      final calc = TapTempoCalculator(resetGap: const Duration(seconds: 2));
      final t0 = DateTime(2026);
      calc.tap(t0);
      calc.tap(t0.add(const Duration(milliseconds: 500))); // 120 BPM
      // 隔很久再敲，应重置，下一次又不足两拍。
      final afterGap = calc.tap(t0.add(const Duration(seconds: 10)));
      expect(afterGap, isNull);
    });

    test('结果夹在 30..300 范围内', () {
      final calc = TapTempoCalculator();
      final t0 = DateTime(2026);
      calc.tap(t0);
      // 间隔 10ms = 6000 BPM，应夹到 300。
      final bpm = calc.tap(t0.add(const Duration(milliseconds: 10)));
      expect(bpm, 300);
    });
  });
}
