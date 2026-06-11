import 'package:flutter/material.dart';
import '../../../../core/timing/rhythm_pattern.dart';

const _kAmber = Color(0xFFE8A435);
const _kAmberDim = Color(0x55E8A435);
const _kBg = Color(0xFF0D0D0D);
const _kSurface = Color(0xFF181818);
const _kText = Color(0xFFDDD5C8);
const _kTextDim = Color(0x88DDD5C8);

class RhythmGridPicker extends StatelessWidget {
  final List<int> selectedIndices; // [beat0Index, beat1Index, beat2Index, beat3Index]
  final int currentBeat; // -1 when not playing, 0-3 when playing
  final ValueChanged<int> onColumnChanged; // (columnIndex, patternIndex)

  const RhythmGridPicker({
    super.key,
    required this.selectedIndices,
    required this.currentBeat,
    required this.onColumnChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: List.generate(4, (columnIndex) {
          return Expanded(
            child: _buildColumn(columnIndex),
          );
        }),
      ),
    );
  }

  Widget _buildColumn(int columnIndex) {
    final isActive = currentBeat == columnIndex;
    final selectedIndex = selectedIndices[columnIndex];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isActive ? _kAmberDim : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? _kAmber : _kSurface,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Beat number label
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${columnIndex + 1}',
              style: TextStyle(
                color: isActive ? _kAmber : _kTextDim,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Wheel picker
          Expanded(
            child: ListWheelScrollView.useDelegate(
              itemExtent: 80,
              diameterRatio: 1.5,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              controller: FixedExtentScrollController(
                initialItem: selectedIndex,
              ),
              onSelectedItemChanged: (index) {
                onColumnChanged(columnIndex * 100 + index); // encode both values
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  if (index < 0 || index >= kRhythmPresets.length) {
                    return null;
                  }
                  final pattern = kRhythmPresets[index];
                  final isSelected = index == selectedIndex;

                  return Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: isSelected ? _kSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? _kAmber : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        pattern.glyph,
                        style: TextStyle(
                          fontFamily: 'Musisync',
                          fontSize: isSelected ? 36 : 28,
                          color: isSelected ? _kText : _kTextDim,
                          height: 1.0,
                        ),
                      ),
                    ),
                  );
                },
                childCount: kRhythmPresets.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
