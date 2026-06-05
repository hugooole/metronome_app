import 'package:flutter/material.dart';

import 'core/audio/click_player.dart';
import 'data/settings_repository.dart';
import 'features/metronome/state/metronome_controller.dart';
import 'features/metronome/ui/metronome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = MetronomeController(
    player: SoLoudClickPlayer(),
    settings: PrefsSettingsRepository(),
  );

  // 加载音频与上次设置；失败也进入界面（无声仍可视觉练习）。
  try {
    await controller.init();
  } catch (e, st) {
    debugPrint('节拍器初始化失败: $e\n$st');
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
