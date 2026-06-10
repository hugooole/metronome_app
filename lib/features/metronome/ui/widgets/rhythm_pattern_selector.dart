import 'package:flutter/material.dart';

import '../../../../core/timing/rhythm_pattern.dart';

const kMusisync = 'Musisync';

/// A grid of rhythm-pattern cells rendered with the MusiSync font.
/// Each preset's `glyph` is one pre-beamed character.
class RhythmPatternGrid extends StatelessWidget {
  final RhythmPattern selected;
  final ValueChanged<RhythmPattern> onSelect;

  const RhythmPatternGrid({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: kRhythmPresets.map((p) {
        final isSelected = p.id == selected.id;
        final color = isSelected
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: 0.85);
        return GestureDetector(
          onTap: () => onSelect(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primary.withValues(alpha: 0.18)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: scheme.primary, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              p.glyph,
              style: TextStyle(
                fontFamily: kMusisync,
                fontSize: 38,
                color: color,
                height: 1.0,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Bottom-sheet page for choosing a rhythm pattern. Returns nothing; calls
/// [onSelect] and pops on tap.
class RhythmPatternSheet extends StatelessWidget {
  final RhythmPattern selected;
  final ValueChanged<RhythmPattern> onSelect;

  const RhythmPatternSheet({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('节 奏 型', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Flexible(
              child: RhythmPatternGrid(
                selected: selected,
                onSelect: (p) {
                  onSelect(p);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
