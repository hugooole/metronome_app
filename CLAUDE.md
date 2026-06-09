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
- `NativeMetronomeEngine` — delegates entirely to native code on iOS/Android/macOS; Dart only receives beat callbacks via EventChannel for UI updates

**Audio** — platform-split:
- **Web**: `SoLoudClickPlayer` (`lib/core/audio/click_player.dart`) — `flutter_soloud` for low-latency playback
- **iOS/macOS**: `SampleAccurateMetronome.swift` — AVAudioEngine + `playerNode.scheduleBuffer(at: AVAudioTime)` for sample-accurate scheduling
- **Android**: `AudioTrackMetronome.kt` — AudioTrack PCM streaming with 512-frame chunk mixing; beats land at exact sample positions; FLAC assets decoded via MediaCodec

**Feature state** (`lib/features/metronome/state/`) — `MetronomeController` (ChangeNotifier) bridges the engine and UI; `TapTempo` estimates BPM from taps.

**Data** (`lib/data/settings_repository.dart`) — persists BPM and time signature via `shared_preferences`; restored on launch.

Entry point is `lib/main.dart`, which wires up dependency injection.

## Android notes

- FLAC assets must not be compressed in the APK: `androidResources { noCompress += listOf("flac") }` in `build.gradle.kts`
- Build requires `LD_LIBRARY_PATH=/home/ps/Android/Sdk/build-tools/36.0.0/lib64:$LD_LIBRARY_PATH flutter run` on Linux due to system `libc++.so` stub
- Native plugin: `MetronomePlugin.kt` (MethodChannel + EventChannel) → `AudioTrackMetronome.kt`
