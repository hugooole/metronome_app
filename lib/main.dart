import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/audio/click_player.dart';
import 'data/settings_repository.dart';
import 'features/metronome/state/metronome_controller.dart';
import 'features/metronome/ui/metronome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final player = kIsWeb ? SoLoudClickPlayer() : NoOpClickPlayer();

  final controller = MetronomeController(
    player: player,
    settings: PrefsSettingsRepository(),
  );

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
      theme: _buildTheme(),
      home: MetronomeScreen(controller: controller),
    );
  }

  ThemeData _buildTheme() {
    const amber = Color(0xFFE8A435);
    const bg = Color(0xFF0D0D0D);
    const surface = Color(0xFF181818);
    const onSurface = Color(0xFFDDD5C8);

    final cs = ColorScheme.dark(
      primary: amber,
      onPrimary: bg,
      surface: bg,
      onSurface: onSurface,
      surfaceContainerHighest: surface,
      outline: const Color(0xFF2E2E2E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: bg,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      textTheme: const TextTheme(
        titleMedium: TextStyle(
          color: onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 3,
        ),
      ),
    );
  }
}
