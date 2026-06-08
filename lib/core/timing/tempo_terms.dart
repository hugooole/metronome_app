/// Maps a BPM value to its conventional Italian tempo term.
library;

/// Returns the tempo marking for [bpm] per standard Italian conventions.
String tempoTerm(int bpm) {
  if (bpm <= 24) return 'Larghissimo';
  if (bpm <= 40) return 'Grave';
  if (bpm <= 60) return 'Lento';
  if (bpm <= 66) return 'Adagio';
  if (bpm <= 80) return 'Adagietto';
  if (bpm <= 108) return 'Andante';
  if (bpm <= 120) return 'Moderato';
  if (bpm <= 156) return 'Allegro';
  if (bpm <= 176) return 'Vivace';
  if (bpm <= 200) return 'Presto';
  return 'Prestissimo';
}
