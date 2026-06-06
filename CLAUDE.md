# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get       # install dependencies
flutter test          # run all tests
flutter run           # run on connected device/emulator
flutter build apk/ios/web/macos  # platform builds
```

To run a single test file:
```bash
flutter test test/path/to/file_test.dart
```

## Architecture

The app has four layers:

**Timing** (`lib/core/timing/`) — the most critical layer. Uses self-correcting scheduling: theoretical beat time advances by `+= interval` (not reset to actual fire time), preventing drift accumulation. Two implementations behind the `MetronomeEngine` abstract interface:
- `IsolateMetronomeEngine` — production; timing runs in a dedicated Dart Isolate so UI repaints and GC never interfere
- `LocalMetronomeEngine` — tests; same-isolate with injectable `clock` for `fakeAsync` time-travel tests

**Audio** (`lib/core/audio/click_player.dart`) — `flutter_soloud` for low-latency playback; first beat of each bar uses a distinct accented timbre.

**Feature state** (`lib/features/metronome/state/`) — `MetronomeController` (ChangeNotifier) bridges the engine and UI; `TapTempo` estimates BPM from taps.

**Data** (`lib/data/settings_repository.dart`) — persists BPM and time signature via `shared_preferences`; restored on launch.

Entry point is `lib/main.dart`, which wires up dependency injection.
