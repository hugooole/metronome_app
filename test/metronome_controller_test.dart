import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/audio/click_player.dart';
import 'package:metronome_app/core/audio/timbre.dart';
import 'package:metronome_app/core/timing/local_metronome_engine.dart';
import 'package:metronome_app/core/timing/metronome_engine.dart';
import 'package:metronome_app/features/metronome/state/metronome_controller.dart';
import 'package:metronome_app/data/settings_repository.dart';

class FakeClickPlayer implements ClickPlayer {
  int accentCount = 0;
  int normalCount = 0;
  @override Future<void> init() async {}
  @override void playAccent() => accentCount++;
  @override void playNormal() => normalCount++;
  @override void setTimbre(Timbre t) {}
  @override void dispose() {}
}

class FakeSettings implements SettingsRepository {
  MetronomeSettings stored;
  FakeSettings([this.stored = MetronomeSettings.defaults]);
  @override Future<MetronomeSettings> load() async => stored;
  @override Future<void> save(MetronomeSettings s) async => stored = s;
}

void main() {
  group('MetronomeController', () {
    test('init restores saved settings', () async {
      final c = MetronomeController(
        player: FakeClickPlayer(),
        settings: FakeSettings(
          const MetronomeSettings(bpm: 90, beatsPerBar: 3),
        ),
      );
      await c.init();
      expect(c.bpm, 90);
      expect(c.beatsPerBar, 3);
    });

    test('setBpm clamps to the valid range and persists', () async {
      final settings = FakeSettings();
      final c = MetronomeController(player: FakeClickPlayer(), settings: settings);
      await c.init();
      c.setBpm(9999);
      expect(c.bpm, kMaxBpm);
      expect(settings.stored.bpm, kMaxBpm);
      c.setBpm(1);
      expect(c.bpm, kMinBpm);
    });

    test('accent calls playAccent and normal beats call playNormal', () {
      final player = FakeClickPlayer();
      final c = MetronomeController(
        player: player,
        settings: FakeSettings(const MetronomeSettings(bpm: 120, beatsPerBar: 4)),
        engine: LocalMetronomeEngine(onBeat: (_) {}),
      );
      fakeAsync((async) {
        c.start();
        async.elapse(const Duration(milliseconds: 2100)); // ~5 beats
        c.stop();
      });
      expect(player.accentCount, greaterThanOrEqualTo(1));
      expect(player.normalCount, greaterThanOrEqualTo(3));
    });

    test('after stop, isPlaying is false and currentBeat resets', () {
      final c = MetronomeController(
        player: FakeClickPlayer(),
        settings: FakeSettings(),
        engine: LocalMetronomeEngine(onBeat: (_) {}),
      );
      fakeAsync((async) {
        c.start();
        expect(c.isPlaying, isTrue);
        async.elapse(const Duration(milliseconds: 600));
        c.stop();
      });
      expect(c.isPlaying, isFalse);
      expect(c.currentBeat, -1);
    });

    test('setPattern persists and updates engine', () async {
      final settings = FakeSettings();
      final c = MetronomeController(
        player: FakeClickPlayer(),
        settings: settings,
        engine: LocalMetronomeEngine(onBeat: (_) {}),
      );
      await c.init();
      c.setPattern(kRhythmPresets[1]); // 八分
      expect(c.pattern.id, 'eighth');
      expect(settings.stored.patternId, 'eighth');
    });
  });
}
