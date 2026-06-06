/// Click timbres (sound voices) the metronome can play.
library;

/// A selectable percussion voice.
///
/// A timbre provides an [accentAsset] (first beat of the bar) and a
/// [normalAsset] (other beats). When the two are the same file the player
/// distinguishes accent/normal by volume + pitch; when they differ (e.g. a
/// real drum kit: snare on the downbeat, hi-hat elsewhere) the samples are
/// played as-is with [pitched] off so they keep their natural tone.
class Timbre {
  final String id;
  final String name;
  final String accentAsset;
  final String normalAsset;

  /// Whether the normal beat should be pitched up (only meaningful when accent
  /// and normal share one sample). Real multi-sample kits set this false.
  final bool pitched;

  const Timbre({
    required this.id,
    required this.name,
    required this.accentAsset,
    required this.normalAsset,
    this.pitched = true,
  });

  /// Convenience for a single-sample timbre (same file for accent and normal,
  /// differentiated by volume + pitch).
  const Timbre.single({
    required this.id,
    required this.name,
    required String asset,
  })  : accentAsset = asset,
        normalAsset = asset,
        pitched = true;

  /// All distinct asset paths this timbre needs preloaded.
  Iterable<String> get assets =>
      accentAsset == normalAsset ? [accentAsset] : [accentAsset, normalAsset];
}

const Timbre kDefaultTimbre = Timbre.single(
  id: 'click',
  name: '经典',
  asset: 'assets/sounds/click.flac',
);

/// Built-in timbres. The asset paths must live under `assets/sounds/`
/// (registered as a directory in pubspec.yaml).
const List<Timbre> kTimbres = [
  kDefaultTimbre,
  Timbre(
    id: 'drum',
    name: '爵士鼓',
    accentAsset: 'assets/sounds/drum_accent.flac', // snare on the downbeat
    normalAsset: 'assets/sounds/drum_normal.flac', // hi-hat elsewhere
    pitched: false,
  ),
];

/// Looks up a timbre by [id], falling back to [kDefaultTimbre].
Timbre timbreById(String id) =>
    kTimbres.firstWhere((t) => t.id == id, orElse: () => kDefaultTimbre);
