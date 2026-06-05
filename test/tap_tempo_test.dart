import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/features/metronome/state/tap_tempo.dart';

void main() {
  group('TapTempoCalculator', () {
    test('returns null with fewer than two taps', () {
      final calc = TapTempoCalculator();
      expect(calc.tap(DateTime(2026)), isNull);
    });

    test('even 500ms taps yield 120 BPM', () {
      final calc = TapTempoCalculator();
      final t0 = DateTime(2026, 1, 1, 0, 0, 0);
      calc.tap(t0);
      final bpm = calc.tap(t0.add(const Duration(milliseconds: 500)));
      expect(bpm, 120);
    });

    test('averaging multiple taps gives a stable result', () {
      final calc = TapTempoCalculator();
      var t = DateTime(2026);
      int? bpm;
      for (var i = 0; i < 5; i++) {
        bpm = calc.tap(t);
        t = t.add(const Duration(milliseconds: 600)); // 100 BPM
      }
      expect(bpm, 100);
    });

    test('restarts the calculation after resetGap', () {
      final calc = TapTempoCalculator(resetGap: const Duration(seconds: 2));
      final t0 = DateTime(2026);
      calc.tap(t0);
      calc.tap(t0.add(const Duration(milliseconds: 500))); // 120 BPM
      // After a long gap it should reset, so the next tap is short of two taps.
      final afterGap = calc.tap(t0.add(const Duration(seconds: 10)));
      expect(afterGap, isNull);
    });

    test('result is clamped to the 30..300 range', () {
      final calc = TapTempoCalculator();
      final t0 = DateTime(2026);
      calc.tap(t0);
      // A 10ms interval = 6000 BPM, should clamp to 300.
      final bpm = calc.tap(t0.add(const Duration(milliseconds: 10)));
      expect(bpm, 300);
    });
  });
}
