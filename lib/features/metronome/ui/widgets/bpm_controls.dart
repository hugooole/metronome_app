import 'package:flutter/material.dart';

import '../../state/metronome_controller.dart';

/// BPM slider + ±1 / ±5 fine-adjust buttons.
class BpmControls extends StatelessWidget {
  final MetronomeController controller;
  const BpmControls({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          min: kMinBpm.toDouble(),
          max: kMaxBpm.toDouble(),
          value: controller.bpm.toDouble().clamp(
                kMinBpm.toDouble(),
                kMaxBpm.toDouble(),
              ),
          onChanged: (v) => controller.setBpm(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NudgeButton(label: '-5', onTap: () => controller.nudgeBpm(-5)),
            NudgeButton(label: '-1', onTap: () => controller.nudgeBpm(-1)),
            const SizedBox(width: 24),
            NudgeButton(label: '+1', onTap: () => controller.nudgeBpm(1)),
            NudgeButton(label: '+5', onTap: () => controller.nudgeBpm(5)),
          ],
        ),
      ],
    );
  }
}

class NudgeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const NudgeButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: 56,
        height: 48,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(label),
        ),
      ),
    );
  }
}

/// Time signature (beats per bar) selector.
class BeatsPerBarSelector extends StatelessWidget {
  final MetronomeController controller;
  const BeatsPerBarSelector({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: kBeatsPerBarOptions
          .map((n) => ButtonSegment(value: n, label: Text('$n/4')))
          .toList(),
      selected: {controller.beatsPerBar},
      onSelectionChanged: (s) => controller.setBeatsPerBar(s.first),
    );
  }
}

/// Start / stop primary button.
class StartStopButton extends StatelessWidget {
  final MetronomeController controller;
  const StartStopButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final playing = controller.isPlaying;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: controller.toggle,
        icon: Icon(playing ? Icons.stop : Icons.play_arrow, size: 28),
        label: Text(
          playing ? '停止' : '开始',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
