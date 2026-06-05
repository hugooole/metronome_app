import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/audio/click_player.dart';
import 'package:metronome_app/data/settings_repository.dart';
import 'package:metronome_app/features/metronome/state/metronome_controller.dart';
import 'package:metronome_app/features/metronome/ui/metronome_screen.dart';

class _FakePlayer implements ClickPlayer {
  @override
  Future<void> init() async {}
  @override
  void playAccent() {}
  @override
  void playNormal() {}
  @override
  void dispose() {}
}

class _FakeSettings implements SettingsRepository {
  @override
  Future<MetronomeSettings> load() async => MetronomeSettings.defaults;
  @override
  Future<void> save(MetronomeSettings s) async {}
}

void main() {
  testWidgets('主界面渲染 BPM 与开始按钮，点击切换为停止', (tester) async {
    final controller = MetronomeController(
      player: _FakePlayer(),
      settings: _FakeSettings(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: MetronomeScreen(controller: controller)),
    );

    // 默认 120 BPM 显示。
    expect(find.text('120'), findsOneWidget);
    expect(find.text('BPM'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);

    // 点击开始 → 变停止。
    await tester.tap(find.text('开始'));
    await tester.pump();
    expect(find.text('停止'), findsOneWidget);

    controller.stop();
  });
}
