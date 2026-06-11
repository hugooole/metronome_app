import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/timing/tempo_terms.dart';
import '../state/metronome_controller.dart';
import '../state/tap_tempo.dart';
import 'widgets/rhythm_pattern_selector.dart';
import 'widgets/timbre_sheet.dart';
import 'widgets/time_signature_sheet.dart';

// ── palette ──────────────────────────────────────────────────────────────────
const _kAmber = Color(0xFFE8A435);
const _kAmberDim = Color(0x55E8A435);
const _kBg = Color(0xFF0D0D0D);
const _kSurface = Color(0xFF181818);
const _kText = Color(0xFFDDD5C8);
const _kTextDim = Color(0x88DDD5C8);
const _kBorder = Color(0xFF2A2A2A);

class MetronomeScreen extends StatefulWidget {
  final MetronomeController controller;

  const MetronomeScreen({super.key, required this.controller});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen>
    with SingleTickerProviderStateMixin {
  final _tapTempo = TapTempoCalculator();
  late final AnimationController _pulseCtrl;
  int _lastBeat = -1;

  MetronomeController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    c.addListener(_onBeat);
  }

  void _onBeat() {
    if (c.currentBeat != _lastBeat && c.currentBeat >= 0) {
      _lastBeat = c.currentBeat;
      _pulseCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    c.removeListener(_onBeat);
    _pulseCtrl.dispose();
    super.dispose();
  }

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
      backgroundColor: _kBg,
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _TopBar(
                    timbreName: c.timbre.name,
                    onTimbre: _openTimbre,
                    onTap: _onTap,
                  ),
                  Expanded(
                    child: Center(
                      child: _Dial(
                        bpm: c.bpm,
                        onChanged: c.setBpm,
                        pulseCtrl: _pulseCtrl,
                        isPlaying: c.isPlaying,
                      ),
                    ),
                  ),
                  _BeatDots(
                    beatsPerBar: c.beatsPerBar,
                    currentBeat: c.currentBeat,
                  ),
                  const SizedBox(height: 20),
                  _BottomBar(
                    controller: c,
                    onTimeSignature: _openTimeSignature,
                    onRhythm: _openRhythm,
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── beat dots ────────────────────────────────────────────────────────────────

class _BeatDots extends StatefulWidget {
  final int beatsPerBar;
  final int currentBeat;

  const _BeatDots({required this.beatsPerBar, required this.currentBeat});

  @override
  State<_BeatDots> createState() => _BeatDotsState();
}

class _BeatDotsState extends State<_BeatDots> {
  int _prev = -1;

  @override
  void didUpdateWidget(_BeatDots old) {
    super.didUpdateWidget(old);
    if (old.currentBeat != widget.currentBeat) _prev = old.currentBeat;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.beatsPerBar, (i) {
          final isActive = i == widget.currentBeat;
          final isDownbeat = i == 0;
          final snap = isActive && _prev != widget.currentBeat;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: AnimatedContainer(
              duration:
                  snap ? Duration.zero : const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              width: isActive
                  ? (isDownbeat ? 22 : 16)
                  : (isDownbeat ? 13 : 9),
              height: isActive
                  ? (isDownbeat ? 22 : 16)
                  : (isDownbeat ? 13 : 9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? _kAmber
                    : isDownbeat
                        ? _kAmberDim
                        : const Color(0xFF2E2E2E),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _kAmber.withValues(alpha: 0.6),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── top bar ──────────────────────────────────────────────────────────────────

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
        _GhostButton(
          onPressed: onTimbre,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.graphic_eq_rounded, size: 15, color: _kTextDim),
              const SizedBox(width: 6),
              Text(
                timbreName,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextDim,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        _GhostButton(
          onPressed: onTap,
          child: const Text(
            'TAP',
            style: TextStyle(
              fontSize: 13,
              color: _kAmber,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }
}

// ── dial ─────────────────────────────────────────────────────────────────────

class _Dial extends StatefulWidget {
  final int bpm;
  final ValueChanged<int> onChanged;
  final AnimationController pulseCtrl;
  final bool isPlaying;

  const _Dial({
    required this.bpm,
    required this.onChanged,
    required this.pulseCtrl,
    required this.isPlaying,
  });

  @override
  State<_Dial> createState() => _DialState();
}

class _DialState extends State<_Dial> {
  static const double _sweepDeg = 360;

  Offset _center = Offset.zero;
  double? _prevAngle;
  // visual handle position, decoupled from BPM — can exceed [0,1] at boundaries
  double _visualFraction = 0;
  bool _dragging = false;

  double _angleFromPoint(Offset point) {
    final v = point - _center;
    var deg = math.atan2(v.dy, v.dx) * 180 / math.pi;
    if (deg < 0) deg += 360;
    return deg;
  }

  void _handlePanStart(Offset point) {
    _prevAngle = _angleFromPoint(point);
    _visualFraction = (widget.bpm - kMinBpm) / (kMaxBpm - kMinBpm);
    _dragging = true;
  }

  void _handlePanUpdate(Offset point) {
    if (_prevAngle == null) return;
    var delta = _angleFromPoint(point) - _prevAngle!;
    // Shortest-path wrap to keep delta in (-180, 180]
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _prevAngle = _angleFromPoint(point);

    // handle always follows finger 1:1
    _visualFraction += delta / _sweepDeg;

    // BPM clamps at boundaries; handle keeps moving
    final newBpm = (kMinBpm + _visualFraction.clamp(0.0, 1.0) * (kMaxBpm - kMinBpm)).round();
    if (newBpm != widget.bpm) {
      widget.onChanged(newBpm);
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
    }
    // repaint even when BPM unchanged (handle still moves visually at boundary)
    setState(() {});
  }

  void _handlePanEnd() {
    _prevAngle = null;
    _dragging = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        _center = Offset(size / 2, size / 2);
        final fraction = _dragging ? _visualFraction : ((widget.bpm - kMinBpm) / (kMaxBpm - kMinBpm)).clamp(0.0, 1.0);

        return GestureDetector(
          onTapDown: (d) => _handlePanStart(d.localPosition),
          onPanStart: (d) => _handlePanStart(d.localPosition),
          onPanUpdate: (d) => _handlePanUpdate(d.localPosition),
          onPanEnd: (_) => _handlePanEnd(),
          child: AnimatedBuilder(
            animation: widget.pulseCtrl,
            builder: (context, _) {
              final pulse = widget.isPlaying
                  ? (1 - widget.pulseCtrl.value)
                  : 0.0;
              return CustomPaint(
                size: Size(size, size),
                painter: _DialPainter(
                  fraction: fraction,
                  pulseGlow: pulse,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tempoTerm(widget.bpm).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _kTextDim,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.bpm}',
                        style: const TextStyle(
                          fontSize: 88,
                          fontWeight: FontWeight.w200,
                          color: _kText,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'BPM',
                        style: TextStyle(
                          fontSize: 10,
                          color: _kAmber,
                          letterSpacing: 5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  final double fraction;
  final double pulseGlow;

  _DialPainter({
    required this.fraction,
    required this.pulseGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const handleR = 10.0;
    const tickCount = 60;

    final outerR = size.width / 2 - handleR - 8;
    final innerR = outerR - 20;

    // filled center
    canvas.drawCircle(center, innerR - 2, Paint()..color = _kSurface);

    // ambient glow on beat — three layers for depth
    if (pulseGlow > 0) {
      canvas.drawCircle(
        center, outerR + 30,
        Paint()
          ..color = _kAmber.withValues(alpha: pulseGlow * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
      );
      canvas.drawCircle(
        center, outerR + 12,
        Paint()
          ..color = _kAmber.withValues(alpha: pulseGlow * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawCircle(
        center, outerR,
        Paint()
          ..color = _kAmber.withValues(alpha: pulseGlow * 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // tick marks — full 360°
    final tickPaint = Paint()
      ..color = const Color(0xFF303030)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < tickCount; i++) {
      final angle = 2 * math.pi * i / tickCount;
      final isMajor = i % 5 == 0;
      final len = isMajor ? 10.0 : 5.0;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * (innerR - 5);
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (innerR - 5 - len);
      canvas.drawLine(outer, inner, tickPaint);
    }

    // track circle
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..color = const Color(0xFF232323)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // handle — starts at top (-90°), goes clockwise
    final handleAngle = -math.pi / 2 + 2 * math.pi * fraction;
    final handlePt = center + Offset(math.cos(handleAngle), math.sin(handleAngle)) * outerR;

    canvas.drawCircle(
      handlePt,
      handleR + 5,
      Paint()
        ..color = _kAmber.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(handlePt, handleR, Paint()..color = _kAmber);
    canvas.drawCircle(handlePt, handleR - 4, Paint()..color = _kBg);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction || old.pulseGlow != pulseGlow;
}

// ── bottom bar ───────────────────────────────────────────────────────────────

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _GhostButton(
          onPressed: onTimeSignature,
          child: Text(
            '${controller.beatsPerBar}/4',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w300,
              color: _kText,
              letterSpacing: 1,
            ),
          ),
        ),
        _PlayButton(isPlaying: playing, onPressed: controller.toggle),
        _GhostButton(
          onPressed: onRhythm,
          child: Text(
            controller.pattern.glyph,
            style: const TextStyle(fontFamily: 'Musisync', fontSize: 28),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPressed;

  const _PlayButton({required this.isPlaying, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlaying ? _kAmber : _kSurface,
          border: Border.all(
            color: isPlaying ? _kAmber : const Color(0xFF3A3A3A),
            width: 1.5,
          ),
          boxShadow: isPlaying
              ? [
                  BoxShadow(
                    color: _kAmber.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 36,
          color: isPlaying ? _kBg : _kText,
        ),
      ),
    );
  }
}

// ── ghost button ─────────────────────────────────────────────────────────────

class _GhostButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _GhostButton({required this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
