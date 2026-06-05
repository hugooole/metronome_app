import 'package:flutter/material.dart';

/// 拍点视觉指示：一排圆点，当前拍高亮，第一拍（强拍）用强调色。
class BeatIndicator extends StatelessWidget {
  final int beatsPerBar;
  final int currentBeat;

  const BeatIndicator({
    super.key,
    required this.beatsPerBar,
    required this.currentBeat,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(beatsPerBar, (i) {
        final isActive = i == currentBeat;
        final isAccent = i == 0;
        final Color color;
        if (isActive) {
          color = isAccent ? scheme.error : scheme.primary;
        } else {
          color = scheme.surfaceContainerHighest;
        }
        final double size = isActive ? 28 : 20;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isAccent
                ? Border.all(color: scheme.error, width: 2)
                : null,
          ),
        );
      }),
    );
  }
}
