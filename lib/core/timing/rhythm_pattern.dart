/// Rhythm pattern — subdivides each beat into slots.
///
/// Non-triplet patterns have 4 slots (sixteenth subdivision).
/// Triplet patterns have 3 slots (triplet subdivision).
library;

/// What sound (if any) a subdivision slot produces.
enum SlotType { accent, normal, rest }

/// A rhythm pattern: variable slots per beat, cycled across every beat in the bar.
///
/// Non-triplet patterns use 4 slots (sixteenth subdivision).
/// Triplet patterns use 3 slots (triplet subdivision).
///
/// [glyph] is the single MusiSync character that visually represents this
/// one-beat rhythm cell (the font ships pre-beamed glyphs, one per char).
class RhythmPattern {
  final String id;
  final String name;

  /// 3 or 4 slots, applied to every beat (slot[0] of beat 0 is the bar accent).
  final List<SlotType> slots;

  /// MusiSync glyph char for this cell.
  final String glyph;

  const RhythmPattern({
    required this.id,
    required this.name,
    required this.slots,
    required this.glyph,
  });
}

/// Built-in presets — 15 subdivision cells matching the reference design,
/// laid out in the same order the selector grid shows them (4 rows).
///
/// Slot legend: a=accent (only ever on beat 0 / slot 0), n=normal, _=rest.
/// 4-slot patterns: sixteenth subdivision. 3-slot patterns: triplet subdivision.
/// `glyph` is the MusiSync char that draws the pre-beamed cell (visual only;
/// `slots` alone determine the sound timing).
const List<RhythmPattern> kRhythmPresets = [
  // ——— row 1 ———
  // ♩  quarter
  RhythmPattern(
    id: 'quarter',
    name: '四分',
    slots: [SlotType.accent, SlotType.rest, SlotType.rest, SlotType.rest],
    glyph: 'q',
  ),
  // ♫  two eighths
  RhythmPattern(
    id: 'eighth',
    name: '八分',
    slots: [SlotType.accent, SlotType.rest, SlotType.normal, SlotType.rest],
    glyph: 'n',
  ),
  // 𝄾♪  eighth-rest + eighth
  RhythmPattern(
    id: 'eighth_rest',
    name: '八分休止',
    slots: [SlotType.rest, SlotType.rest, SlotType.normal, SlotType.rest],
    glyph: 'E',
  ),
  // triplet — three equal
  RhythmPattern(
    id: 'triplet',
    name: '三连音',
    slots: [SlotType.accent, SlotType.normal, SlotType.normal],
    glyph: 'T',
  ),
  // ——— row 2: triplet variants ———
  // triplet: rest + 2 notes  (𝄻 ♪♪)
  RhythmPattern(
    id: 'triplet_rest1',
    name: '三连休前',
    slots: [SlotType.rest, SlotType.normal, SlotType.normal],
    glyph: 'Õ',
  ),
  // triplet: note - rest - note  (♪ 𝄻 ♪)
  RhythmPattern(
    id: 'triplet_13',
    name: '三连一三',
    slots: [SlotType.accent, SlotType.rest, SlotType.normal],
    glyph: '¼',
  ),
  // triplet: 2 notes + rest  (♪♪ 𝄻)
  RhythmPattern(
    id: 'triplet_12',
    name: '三连一二',
    slots: [SlotType.accent, SlotType.normal, SlotType.rest],
    glyph: 'Ó',
  ),
  // triplet: rest - note - rest (middle only)  (𝄻 ♪ 𝄻)
  RhythmPattern(
    id: 'triplet_mid',
    name: '三连中音',
    slots: [SlotType.rest, SlotType.normal, SlotType.rest],
    glyph: 'Ò',
  ),
  // ——— row 3 ———
  // four sixteenths
  RhythmPattern(
    id: 'sixteenth',
    name: '十六分',
    slots: [SlotType.accent, SlotType.normal, SlotType.normal, SlotType.normal],
    glyph: 'y',
  ),
  // sixteenth syncopation: rest-note-rest-note  (𝄿♬ 𝄿♬)
  RhythmPattern(
    id: 'sixteenth_sync',
    name: '十六切分',
    slots: [SlotType.rest, SlotType.normal, SlotType.rest, SlotType.normal],
    glyph: 's',
  ),
  // eighth + two sixteenths  (long-short-short)
  RhythmPattern(
    id: 'eighth_two16',
    name: '八分双十六',
    slots: [SlotType.accent, SlotType.rest, SlotType.normal, SlotType.normal],
    glyph: 'm',
  ),
  // two sixteenths + eighth  (short-short-long)
  RhythmPattern(
    id: 'two16_eighth',
    name: '双十六八分',
    slots: [SlotType.accent, SlotType.normal, SlotType.normal, SlotType.rest],
    glyph: 'M',
  ),
  // ——— row 4 ———
  // dotted-eighth + sixteenth  (long-short)
  RhythmPattern(
    id: 'dotted',
    name: '附点八分',
    slots: [SlotType.accent, SlotType.rest, SlotType.rest, SlotType.normal],
    glyph: 'o',
  ),
  // sixteenth + dotted-eighth  (short-long)
  RhythmPattern(
    id: 'rev_dotted',
    name: '十六附点',
    slots: [SlotType.accent, SlotType.normal, SlotType.rest, SlotType.rest],
    glyph: 'O',
  ),
  // two sixteenths + eighth, variant beaming  (short-short-long)
  RhythmPattern(
    id: 'two16_eighth_alt',
    name: '双十六八分2',
    slots: [SlotType.accent, SlotType.normal, SlotType.normal, SlotType.rest],
    glyph: 'N',
  ),
];

/// Default pattern (四分) — used as the MetronomeConfig default.
const RhythmPattern kDefaultPattern = RhythmPattern(
  id: 'quarter',
  name: '四分',
  slots: [SlotType.accent, SlotType.rest, SlotType.rest, SlotType.rest],
  glyph: 'q',
);

RhythmPattern patternById(String id) =>
    kRhythmPresets.firstWhere((p) => p.id == id,
        orElse: () => kDefaultPattern);
