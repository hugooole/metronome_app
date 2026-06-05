/// Isolate-based timing engine implementation (production).
///
/// Timing runs in a dedicated Isolate (see [timer_isolate.dart]) so the main
/// thread's UI repaints, animations, and GC don't interfere with the beat.
/// Beats are sent back to the main isolate via SendPort, then trigger sound and
/// UI updates.
library;

// The constructor intentionally uses named params + an initializer list
// (fields are private); this reads better than initializing formals.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:isolate';

import 'metronome_engine.dart';
import 'timer_isolate.dart';

class IsolateMetronomeEngine implements MetronomeEngine {
  void Function(BeatEvent event) _onBeat;
  MetronomeConfig _config;

  Isolate? _isolate;
  ReceivePort? _fromIsolate;
  StreamSubscription? _sub;
  SendPort? _control; // sends config updates / stop to the Isolate

  IsolateMetronomeEngine({
    required void Function(BeatEvent event) onBeat,
    MetronomeConfig config = const MetronomeConfig(),
  })  : _onBeat = onBeat,
        _config = config;

  @override
  set onBeatHandler(void Function(BeatEvent event) handler) =>
      _onBeat = handler;

  @override
  bool get isRunning => _isolate != null;

  @override
  void start() {
    if (isRunning) return;
    // Spawn the Isolate asynchronously; start() keeps a sync signature to match
    // the interface.
    unawaited(_spawn());
  }

  Future<void> _spawn() async {
    final fromIsolate = ReceivePort();
    _fromIsolate = fromIsolate;

    _sub = fromIsolate.listen((msg) {
      if (msg is SendPort) {
        _control = msg; // control port sent back by the Isolate
      } else if (msg is List) {
        // Beat message: [beatIndex, isAccent, scheduledMicros]
        _onBeat(BeatEvent(
          beatIndex: msg[0] as int,
          isAccent: (msg[1] as int) == 1,
          scheduledMicros: msg[2] as int,
        ));
      }
    });

    _isolate = await Isolate.spawn(
      timerIsolateEntry,
      TimerInit(
        toMain: fromIsolate.sendPort,
        bpm: _config.bpm,
        beatsPerBar: _config.beatsPerBar,
      ),
    );
  }

  @override
  void stop() {
    _control?.send('stop');
    _sub?.cancel();
    _sub = null;
    _fromIsolate?.close();
    _fromIsolate = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _control = null;
  }

  @override
  void updateConfig(MetronomeConfig next) {
    _config = next;
    _control?.send(ConfigUpdate(next.bpm, next.beatsPerBar));
  }

  @override
  void dispose() => stop();
}
