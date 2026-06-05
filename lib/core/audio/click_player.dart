/// Metronome sound layer.
///
/// Exposes the [ClickPlayer] abstract interface so the state layer depends on
/// the interface, not on flutter_soloud. Benefits: tests can inject a fake
/// player; swapping the audio library later only changes the implementation,
/// not the layers above.
library;

import 'package:flutter_soloud/flutter_soloud.dart';

/// Metronome sound interface.
abstract class ClickPlayer {
  /// Load audio resources; must be called once before playing.
  Future<void> init();

  /// Play the accent (first beat of the bar).
  void playAccent();

  /// Play a normal beat.
  void playNormal();

  /// Release resources.
  void dispose();
}

/// flutter_soloud-based implementation.
///
/// Design notes:
/// - Uses a single click source (the user-provided unfa 2kHz pulse, FLAC,
///   ~50ms).
/// - Accent vs. normal beats are distinguished not by two asset files but by
///   **volume + playback speed (pitch)**: the accent plays at normal speed and
///   full volume; the normal beat plays faster (higher-pitched, shorter) at
///   slightly lower volume. This cleanly distinguishes bars from a single file
///   and avoids mismatched assets.
/// - The click is short, preloaded as an in-memory source, so playback has zero
///   disk IO and minimal latency.
/// - Each playback is a one-shot; handles are not reused, avoiding mutual
///   interruption.
class SoLoudClickPlayer implements ClickPlayer {
  static const String _clickAsset = 'assets/sounds/click.flac';

  // Volume and pitch (relative playback speed) differences for accent/normal.
  static const double _accentVolume = 1.0;
  static const double _normalVolume = 0.6;
  static const double _accentSpeed = 1.0;
  static const double _normalSpeed = 1.5; // higher pitch feels "lighter"

  final SoLoud _soloud = SoLoud.instance;

  AudioSource? _click;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (!_soloud.isInitialized) {
      await _soloud.init();
    }
    _click = await _soloud.loadAsset(_clickAsset);
    _ready = true;
  }

  @override
  void playAccent() => _playClick(_accentVolume, _accentSpeed);

  @override
  void playNormal() => _playClick(_normalVolume, _normalSpeed);

  void _playClick(double volume, double speed) {
    final src = _click;
    if (!_ready || src == null) return;
    // Start paused to set parameters, then resume — ensures volume/pitch take
    // effect before any sound is produced.
    final handle = _soloud.play(src, volume: volume, paused: true);
    _soloud.setRelativePlaySpeed(handle, speed);
    _soloud.setPause(handle, false);
  }

  @override
  void dispose() {
    final src = _click;
    if (src != null) _soloud.disposeSource(src);
    _click = null;
    _ready = false;
  }
}
