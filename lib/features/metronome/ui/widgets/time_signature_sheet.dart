import 'package:flutter/material.dart';

import '../../state/metronome_controller.dart';

/// Bottom-sheet page for choosing the time signature (beats per bar).
/// Renders each option as a card showing "n/4".
class TimeSignatureSheet extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const TimeSignatureSheet({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('拍  号', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: kBeatsPerBarOptions.map((n) {
                final isSelected = n == selected;
                return GestureDetector(
                  onTap: () {
                    onSelect(n);
                    Navigator.of(context).pop();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primary.withValues(alpha: 0.18)
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: scheme.primary, width: 1.5)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$n/4',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
