# Metronome

A cross-platform metronome practice app built with Flutter, focused on **timing precision**.

## Features

- **BPM control**: 30–300, slider + ±1 / ±5 fine adjustment
- **Time signatures**: 2/4, 3/4, 4/4, 6/8
- **Accented downbeat**: the first beat of each bar has a distinct timbre
- **Tap Tempo**: tap repeatedly to estimate BPM automatically
- **Visual beat indicator**: highlights the current beat in real time, with the accent emphasized
- **Settings memory**: restores the last BPM and time signature on launch

## Design Notes

### Drift-free timing

The core challenge of a metronome is timing precision. This project does **not** play sound directly inside a timer callback (which jitters). Instead it uses **self-correcting scheduling**: it keeps a "theoretical beat time" that advances by `+= interval`, rather than resetting the baseline to the actual fire time. Even if one check is a few milliseconds late, the next beat's theoretical time is unaffected, so error does not accumulate.

Measured: at 120 BPM over 23 beats, total drift was only -2.31ms with per-beat jitter ≤2.23ms (including Isolate→main-thread communication overhead).

### Isolate isolation

Timing runs in a dedicated Isolate so the main thread's UI repaints, animations, and GC never interfere with the beat. The timing layer is an abstract interface with two implementations:

- `LocalMetronomeEngine`: same-isolate, uses an injectable clock for precise `fakeAsync` unit tests
- `IsolateMetronomeEngine`: dedicated Isolate, used in production

## Project Structure

```
lib/
├── main.dart                          entry point, dependency injection
├── core/
│   ├── timing/
│   │   ├── metronome_engine.dart      abstract interface + BeatEvent/MetronomeConfig
│   │   ├── local_metronome_engine.dart same-isolate implementation (testable)
│   │   ├── isolate_metronome_engine.dart Isolate implementation (production)
│   │   └── timer_isolate.dart         timing core that runs inside the Isolate
│   └── audio/click_player.dart        SoLoud sound layer
├── features/metronome/
│   ├── state/
│   │   ├── metronome_controller.dart  state glue layer (ChangeNotifier)
│   │   └── tap_tempo.dart             Tap Tempo algorithm
│   └── ui/                            screens and widgets
└── data/settings_repository.dart      settings persistence
```

## Tech Stack

- Flutter 3.44.1 / Dart 3.12.1
- [flutter_soloud](https://pub.dev/packages/flutter_soloud) — low-latency audio
- [shared_preferences](https://pub.dev/packages/shared_preferences) — settings persistence
- [clock](https://pub.dev/packages/clock) — injectable clock (for tests)

## Development

```bash
flutter pub get
flutter test          # run all tests
flutter run           # run on a connected device/emulator
```

## Credits

The click sound is by [unfa](https://freesound.org/) (Freesound). The Isolate-isolation approach for timing was inspired by [reliable_interval_timer](https://github.com/inf0rmatix/reliable_interval_timer).
