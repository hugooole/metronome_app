import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/audio/click_player.dart';
import 'data/settings_repository.dart';
import 'features/metronome/state/metronome_controller.dart';
import 'features/metronome/ui/metronome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web uses Dart timing + Dart audio; native platforms use native audio.
  final player = kIsWeb ? SoLoudClickPlayer() : NoOpClickPlayer();

  final controller = MetronomeController(
    player: player,
    settings: PrefsSettingsRepository(),
  );

  // Load audio and last settings; enter the UI even on failure (silent but
  // still usable for visual practice).
  try {
    await controller.init();
  } catch (e, st) {
    debugPrint('Metronome init failed: $e\n$st');
  }

  runApp(MetronomeApp(controller: controller));
}

class MetronomeApp extends StatelessWidget {
  final MetronomeController controller;

  const MetronomeApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '节拍器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: MetronomeScreen(controller: controller),
    );
  }
}
