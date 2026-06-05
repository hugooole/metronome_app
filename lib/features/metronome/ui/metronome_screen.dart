import 'package:flutter/material.dart';

import '../state/metronome_controller.dart';
import '../state/tap_tempo.dart';
import 'widgets/beat_indicator.dart';
import 'widgets/bpm_controls.dart';

/// Metronome main screen.
class MetronomeScreen extends StatefulWidget {
  final MetronomeController controller;

  const MetronomeScreen({super.key, required this.controller});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final _tapTempo = TapTempoCalculator();

  MetronomeController get c => widget.controller;

  void _onTap() {
    final bpm = _tapTempo.tap(DateTime.now());
    if (bpm != null) c.setBpm(bpm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('节拍器')),
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  BeatsPerBarSelector(controller: c),
                  const SizedBox(height: 24),
                  BeatIndicator(
                    beatsPerBar: c.beatsPerBar,
                    currentBeat: c.currentBeat,
                  ),
                  const Spacer(),
                  _BpmDisplay(bpm: c.bpm),
                  const SizedBox(height: 16),
                  BpmControls(controller: c),
                  const Spacer(),
                  StartStopButton(controller: c),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _onTap,
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Tap Tempo'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BpmDisplay extends StatelessWidget {
  final int bpm;
  const _BpmDisplay({required this.bpm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$bpm',
          style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
        ),
        Text('BPM', style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
