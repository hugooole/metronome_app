import '../../../core/timing/rhythm_pattern.dart';

/// Represents a single column in the 4-beat grid
class RhythmColumn {
  final int columnIndex; // 0-3 for beats 1-4
  final int selectedPatternIndex;

  const RhythmColumn({
    required this.columnIndex,
    this.selectedPatternIndex = 0,
  });

  RhythmPattern get selectedPattern => kRhythmPresets[selectedPatternIndex];

  RhythmColumn copyWith({
    int? columnIndex,
    int? selectedPatternIndex,
  }) {
    return RhythmColumn(
      columnIndex: columnIndex ?? this.columnIndex,
      selectedPatternIndex: selectedPatternIndex ?? this.selectedPatternIndex,
    );
  }
}

/// Represents the practice grid state (4 columns for 4/4 time)
class PracticeGrid {
  final List<RhythmColumn> columns;
  final int currentBeat; // 0-3, which beat is currently playing

  const PracticeGrid({
    required this.columns,
    this.currentBeat = -1,
  });

  factory PracticeGrid.initial() {
    return PracticeGrid(
      columns: List.generate(
        4,
        (i) => RhythmColumn(columnIndex: i, selectedPatternIndex: 0),
      ),
    );
  }

  RhythmPattern patternForBeat(int beatIndex) {
    if (beatIndex < 0 || beatIndex >= columns.length) {
      return kRhythmPresets.first;
    }
    return columns[beatIndex].selectedPattern;
  }

  PracticeGrid copyWith({
    List<RhythmColumn>? columns,
    int? currentBeat,
  }) {
    return PracticeGrid(
      columns: columns ?? this.columns,
      currentBeat: currentBeat ?? this.currentBeat,
    );
  }

  PracticeGrid updateColumn(int columnIndex, int patternIndex) {
    final updatedColumns = List<RhythmColumn>.from(columns);
    updatedColumns[columnIndex] = RhythmColumn(
      columnIndex: columnIndex,
      selectedPatternIndex: patternIndex,
    );
    return copyWith(columns: updatedColumns);
  }
}
