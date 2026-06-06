/// Metronome sound layer.
///
/// Exposes the [ClickPlayer] abstract interface so the state layer depends on
/// the interface, not on flutter_soloud. Benefits: tests can inject a fake
/// player; swapping the audio library later only changes the implementation,
/// not the layers above.
library;

import 'package:flutter_soloud/flutter_soloud.dart';

import 'timbre.dart';

/// Metronome sound interface.
abstract class ClickPlayer {
  /// Load audio resources; must be called once before playing.
  Future<void> init();

  /// Play the accent (first beat of the bar).
  void playAccent();

  /// Play a normal beat.
  void playNormal();

  /// Switch the active timbre (sound voice) used by subsequent clicks.
  void setTimbre(Timbre timbre);

  /// Release resources.
  void dispose();
}

/// flutter_soloud-based implementation.
///
/// Design notes:
/// - Each [Timbre]'s assets are preloaded at [init] (keyed by asset path) so
///   switching is instant and playback has zero disk IO.
/// - For single-sample timbres (accent and normal share one file) accent vs.
///   normal is distinguished by **volume + playback speed (pitch)**: the accent
///   plays at normal speed and full volume; the normal beat plays faster
///   (higher-pitched, shorter) at slightly lower volume.
/// - For multi-sample timbres (e.g. a drum kit: snare on the downbeat, hi-hat
///   elsewhere) the two files already differ, so they play at full volume and
///   natural pitch ([Timbre.pitched] == false).
/// - Each playback is a one-shot; handles are not reused, avoiding mutual
///   interruption.
class SoLoudClickPlayer implements ClickPlayer {
  // Volume and pitch (relative playback speed) differences for accent/normal,
  // applied only to single-sample (pitched) timbres.
  static const double _accentVolume = 1.0;
  static const double _normalVolume = 0.6;
  static const double _accentSpeed = 1.0;
  static const double _normalSpeed = 1.5; // higher pitch feels "lighter"

  final SoLoud _soloud = SoLoud.instance;

  /// Preloaded sources keyed by asset path.
  final Map<String, AudioSource> _sources = {};
  Timbre _current = kDefaultTimbre;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (!_soloud.isInitialized) {
      await _soloud.init();
    }
    // Preload every asset referenced by any timbre. A missing/failed asset is
    // skipped so the rest still work.
    for (final t in kTimbres) {
      for (final asset in t.assets) {
        if (_sources.containsKey(asset)) continue;
        try {
          _sources[asset] = await _soloud.loadAsset(asset);
        } catch (_) {
          // Asset not present yet — ignore; playback no-ops for it.
        }
      }
    }
    _ready = true;
  }

  @override
  void setTimbre(Timbre timbre) => _current = timbre;

  @override
  void playAccent() {
    final pitched = _current.pitched;
    _play(
      _current.accentAsset,
      volume: pitched ? _accentVolume : 1.0,
      speed: _accentSpeed,
    );
  }

  @override
  void playNormal() {
    final pitched = _current.pitched;
    _play(
      _current.normalAsset,
      volume: pitched ? _normalVolume : 1.0,
      speed: pitched ? _normalSpeed : 1.0,
    );
  }

  void _play(String asset, {required double volume, required double speed}) {
    final src = _sources[asset];
    if (!_ready || src == null) return;
    // Start paused to set parameters, then resume — ensures volume/pitch take
    // effect before any sound is produced.
    final handle = _soloud.play(src, volume: volume, paused: true);
    _soloud.setRelativePlaySpeed(handle, speed);
    _soloud.setPause(handle, false);
  }

  @override
  void dispose() {
    for (final src in _sources.values) {
      _soloud.disposeSource(src);
    }
    _sources.clear();
    _ready = false;
  }
}
