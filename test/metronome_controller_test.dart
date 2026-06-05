import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/audio/click_player.dart';
import 'package:metronome_app/core/timing/local_metronome_engine.dart';
import 'package:metronome_app/features/metronome/state/metronome_controller.dart';
import 'package:metronome_app/data/settings_repository.dart';

/// 假播放器：记录调用次数，不发真声。
class FakeClickPlayer implements ClickPlayer {
  int accentCount = 0;
  int normalCount = 0;
  @override
  Future<void> init() async {}
  @override
  void playAccent() => accentCount++;
  @override
  void playNormal() => normalCount++;
  @override
  void dispose() {}
}

/// 内存设置仓库。
class FakeSettings implements SettingsRepository {
  MetronomeSettings stored;
  FakeSettings([this.stored = MetronomeSettings.defaults]);
  @override
  Future<MetronomeSettings> load() async => stored;
  @override
  Future<void> save(MetronomeSettings s) async => stored = s;
}

void main() {
  group('MetronomeController', () {
    test('init 恢复已保存的设置', () async {
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

    test('setBpm 夹到合法范围并持久化', () async {
      final settings = FakeSettings();
      final c = MetronomeController(
        player: FakeClickPlayer(),
        settings: settings,
      );
      await c.init();
      c.setBpm(9999);
      expect(c.bpm, kMaxBpm);
      expect(settings.stored.bpm, kMaxBpm);
      c.setBpm(1);
      expect(c.bpm, kMinBpm);
    });

    test('播放时强拍调 playAccent，弱拍调 playNormal', () {
      final player = FakeClickPlayer();
      final c = MetronomeController(
        player: player,
        settings: FakeSettings(
          const MetronomeSettings(bpm: 120, beatsPerBar: 4),
        ),
        engine: LocalMetronomeEngine(onBeat: (_) {}),
      );
      fakeAsync((async) {
        c.start();
        async.elapse(const Duration(milliseconds: 2100)); // ~5 拍
        c.stop();
      });
      // 5 拍里强拍出现至少 1 次（第1、5拍），弱拍多次。
      expect(player.accentCount, greaterThanOrEqualTo(1));
      expect(player.normalCount, greaterThanOrEqualTo(3));
    });

    test('stop 后 isPlaying 为 false 且 currentBeat 复位', () {
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
  });
}
