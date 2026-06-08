/// Maps a BPM value to its conventional Italian tempo term.
library;

/// Returns the tempo marking for [bpm] per standard Italian conventions.
String tempoTerm(int bpm) {
  if (bpm <= 0) throw ArgumentError.value(bpm, 'bpm', 'BPM must be greater than 0.');
  if (bpm <= 24) return 'Larghissimo';
  if (bpm <= 40) return 'Grave';
  if (bpm <= 60) return 'Largo';
  if (bpm <= 66) return 'Larghetto';
  if (bpm <= 76) return 'Adagio';
  if (bpm <= 108) return 'Andante';
  if (bpm <= 120) return 'Moderato';
  if (bpm <= 132) return 'Allegretto';
  if (bpm <= 156) return 'Allegro';
  if (bpm <= 176) return 'Vivace';
  if (bpm <= 200) return 'Presto';
  return 'Prestissimo';
}
