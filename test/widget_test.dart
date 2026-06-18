import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metronome_app/core/audio/click_player.dart';
import 'package:metronome_app/core/audio/timbre.dart';
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
  void setTimbre(Timbre t) {}
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
  testWidgets('main screen shows BPM and toggles play/pause icon', (
    tester,
  ) async {
    final player = _FakePlayer();
    final settings = _FakeSettings();
    final controller = MetronomeController(player: player, settings: settings);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MetronomeScreen(
          controller: controller,
          player: player,
          settings: settings,
        ),
      ),
    );

    // Default 120 BPM and the dial are shown.
    expect(find.text('120'), findsOneWidget);
    expect(find.text('BPM'), findsOneWidget);
    // Time-signature button shows 4/4 by default.
    expect(find.text('4/4'), findsOneWidget);

    // Initially shows the play icon; tapping it switches to pause.
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    controller.stop();
  });
}
