import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/timing/tempo_terms.dart';
import '../state/metronome_controller.dart';
import '../state/tap_tempo.dart';
import 'widgets/rhythm_pattern_selector.dart';
import 'widgets/timbre_sheet.dart';
import 'widgets/time_signature_sheet.dart';

/// Metronome main screen — central dial layout (see reference design).
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

  void _openTimeSignature() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => TimeSignatureSheet(
        selected: c.beatsPerBar,
        onSelect: c.setBeatsPerBar,
      ),
    );
  }

  void _openRhythm() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => RhythmPatternSheet(
        selected: c.pattern,
        onSelect: c.setPattern,
      ),
    );
  }

  void _openTimbre() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => TimbreSheet(
        selected: c.timbre,
        onSelect: c.setTimbre,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _TopBar(timbreName: c.timbre.name, onTimbre: _openTimbre, onTap: _onTap),
                  Expanded(
                    child: Center(
                      child: _Dial(bpm: c.bpm, onChanged: c.setBpm),
                    ),
                  ),
                  _BeatBars(
                    beatsPerBar: c.beatsPerBar,
                    currentBeat: c.currentBeat,
                  ),
                  const SizedBox(height: 16),
                  _BottomBar(
                    controller: c,
                    onTimeSignature: _openTimeSignature,
                    onRhythm: _openRhythm,
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

/// A transparent strip of beat bars shown between the dial and the bottom bar.
///
/// One rounded vertical bar per beat, styled after a slider/level look: each
/// bar is filled from the bottom with a flat top edge (a crisp divider line),
/// the bottom corners hugging the rounded outline via a clip. The downbeat
/// (beat 0) is filled fully (strong accent) and the others partially (weak), so
/// the bar's accent structure reads at a glance. The beat currently sounding
/// lights up in the primary color; the rest stay dim. The background is fully
/// transparent so it never occludes the dial above it.
class _BeatBars extends StatelessWidget {
  final int beatsPerBar;
  final int currentBeat; // -1 when stopped/idle

  const _BeatBars({required this.beatsPerBar, required this.currentBeat});

  static const double _barWidth = 30;
  static const double _barHeight = 54;
  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _barHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(beatsPerBar, (i) {
          final isActive = i == currentBeat;
          final isDownbeat = i == 0;
          // Fill fraction encodes accent strength: downbeat full, others weak.
          final fill = isDownbeat ? 1.0 : 0.36;
          final fillColor = isActive
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.30);
          final borderRadius = BorderRadius.circular(_radius);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: _barWidth,
              height: _barHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Bottom-anchored fill with a flat top edge; the clip rounds
                  // its bottom corners to sit flush inside the outline.
                  ClipRRect(
                    borderRadius: borderRadius,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        curve: Curves.easeOut,
                        height: _barHeight * fill,
                        color: fillColor,
                      ),
                    ),
                  ),
                  // Crisp outline on top, always visible.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius,
                      border: Border.all(
                        color: scheme.onSurface.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Soft glow for the active beat, drawn outside the clip.
                  if (isActive)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Top row: timbre (sound voice) selector on the left, TAP on the right.
class _TopBar extends StatelessWidget {
  final String timbreName;
  final VoidCallback onTimbre;
  final VoidCallback onTap;
  const _TopBar({
    required this.timbreName,
    required this.onTimbre,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PillButton(
          width: null,
          onPressed: onTimbre,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.graphic_eq, size: 20),
              const SizedBox(width: 6),
              Text(
                timbreName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        _PillButton(
          onPressed: onTap,
          child: const Text('TAP', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

/// Central circular dial: a knob with a track arc and a draggable handle dot.
/// Drag the handle (or tap anywhere on the ring) to set the BPM. The big
/// number, tempo term and label sit in the middle.
class _Dial extends StatefulWidget {
  final int bpm;
  final ValueChanged<int> onChanged;
  const _Dial({required this.bpm, required this.onChanged});

  @override
  State<_Dial> createState() => _DialState();
}

class _DialState extends State<_Dial> {
  // The track is an arc with a 60° gap centered at the bottom: it starts at
  // 120° and sweeps 300° clockwise (canvas angles: 0° = 3 o'clock, +CW).
  static const double _startDeg = 120;
  static const double _sweepDeg = 300;

  Offset _center = Offset.zero;

  /// Maps a touch [point] to a BPM by its angle around the dial center.
  void _setFromPoint(Offset point) {
    final v = point - _center;
    var deg = math.atan2(v.dy, v.dx) * 180 / math.pi; // -180..180, 0 = right
    if (deg < 0) deg += 360; // 0..360

    // Lift onto the track's continuous range [120, 420].
    double t;
    if (deg >= _startDeg) {
      t = deg; // 120..360
    } else if (deg <= _startDeg + _sweepDeg - 360) {
      t = deg + 360; // 0..60 → 360..420
    } else {
      // In the bottom gap — snap to whichever end is nearer.
      t = (deg < 90) ? _startDeg + _sweepDeg : _startDeg;
    }

    final fraction = ((t - _startDeg) / _sweepDeg).clamp(0.0, 1.0);
    final bpm = (kMinBpm + fraction * (kMaxBpm - kMinBpm)).round();
    widget.onChanged(bpm);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        _center = Offset(size / 2, size / 2);
        final fraction =
            (widget.bpm - kMinBpm) / (kMaxBpm - kMinBpm);
        return GestureDetector(
          onTapDown: (d) => _setFromPoint(d.localPosition),
          onPanStart: (d) => _setFromPoint(d.localPosition),
          onPanUpdate: (d) => _setFromPoint(d.localPosition),
          child: CustomPaint(
            size: Size(size, size),
            painter: _DialPainter(
              fraction: fraction.clamp(0.0, 1.0),
              startDeg: _startDeg,
              sweepDeg: _sweepDeg,
              trackColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              progressColor: scheme.primary,
              handleColor: scheme.primary,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tempoTerm(widget.bpm),
                    style: TextStyle(
                      fontSize: 22,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  Text(
                    '${widget.bpm}',
                    style: const TextStyle(
                        fontSize: 80, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'BPM',
                    style: TextStyle(
                      fontSize: 18,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints the dial: filled center, track arc, progress arc, and handle dot.
class _DialPainter extends CustomPainter {
  final double fraction; // 0..1 position along the track
  final double startDeg;
  final double sweepDeg;
  final Color trackColor;
  final Color progressColor;
  final Color handleColor;
  final Color fillColor;

  _DialPainter({
    required this.fraction,
    required this.startDeg,
    required this.sweepDeg,
    required this.trackColor,
    required this.progressColor,
    required this.handleColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 10.0;
    const handleRadius = 14.0;
    final radius = size.width / 2 - handleRadius - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final startRad = startDeg * math.pi / 180;
    final sweepRad = sweepDeg * math.pi / 180;

    // Filled center.
    canvas.drawCircle(center, radius - stroke / 2, Paint()..color = fillColor);

    // Track (full arc).
    canvas.drawArc(
      rect,
      startRad,
      sweepRad,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress (from start to the handle).
    canvas.drawArc(
      rect,
      startRad,
      sweepRad * fraction,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // Handle dot at the current position.
    final handleRad = startRad + sweepRad * fraction;
    final handle = center +
        Offset(math.cos(handleRad), math.sin(handleRad)) * radius;
    canvas.drawCircle(handle, handleRadius, Paint()..color = handleColor);
    canvas.drawCircle(
      handle,
      handleRadius - 5,
      Paint()..color = fillColor,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
      old.progressColor != progressColor ||
      old.trackColor != trackColor;
}

/// Bottom row: time-signature button, play/pause, rhythm-pattern button.
class _BottomBar extends StatelessWidget {
  final MetronomeController controller;
  final VoidCallback onTimeSignature;
  final VoidCallback onRhythm;

  const _BottomBar({
    required this.controller,
    required this.onTimeSignature,
    required this.onRhythm,
  });

  @override
  Widget build(BuildContext context) {
    final playing = controller.isPlaying;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _PillButton(
          onPressed: onTimeSignature,
          child: Text(
            '${controller.beatsPerBar}/4',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 96,
          height: 64,
          child: FilledButton(
            onPressed: controller.toggle,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 32),
          ),
        ),
        _PillButton(
          onPressed: onRhythm,
          child: Text(
            controller.pattern.glyph,
            style: const TextStyle(fontFamily: kMusisync, fontSize: 26),
          ),
        ),
      ],
    );
  }
}

/// A rounded pill-shaped button with a translucent background.
/// [width] fixes the width; when null the button sizes to its content
/// (with a sensible minimum) and clamps its label to one line.
class _PillButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final double? width;
  const _PillButton({
    required this.child,
    required this.onPressed,
    this.width = 84,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 56,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(72, 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: child,
      ),
    );
  }
}
