/// Maps a BPM value to its conventional Italian tempo term.
library;

/// Returns the tempo marking for [bpm] (e.g. 120 → "Allegretto").
///
/// Ranges follow common metronome conventions; boundaries are approximate.
String tempoTerm(int bpm) {
  if (bpm < 40) return 'Grave';
  if (bpm < 60) return 'Largo';
  if (bpm < 66) return 'Larghetto';
  if (bpm < 76) return 'Adagio';
  if (bpm < 108) return 'Andante';
  if (bpm < 120) return 'Moderato';
  if (bpm < 132) return 'Allegretto';
  if (bpm < 168) return 'Allegro';
  if (bpm < 200) return 'Vivace';
  return 'Presto';
}
