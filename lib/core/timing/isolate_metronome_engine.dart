/// Isolate-based timing engine implementation (production).
library;

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
  SendPort? _control;

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
    unawaited(_spawn());
  }

  Future<void> _spawn() async {
    final fromIsolate = ReceivePort();
    _fromIsolate = fromIsolate;

    _sub = fromIsolate.listen((msg) {
      if (msg is SendPort) {
        _control = msg;
      } else if (msg is List) {
        // Message: [beatIndex, slotIndex, slotTypeIndex, scheduledMicros]
        _onBeat(BeatEvent(
          beatIndex: msg[0] as int,
          slotIndex: msg[1] as int,
          slotType: SlotType.values[msg[2] as int],
          scheduledMicros: msg[3] as int,
        ));
      }
    });

    _isolate = await Isolate.spawn(
      timerIsolateEntry,
      TimerInit(
        toMain: fromIsolate.sendPort,
        bpm: _config.bpm,
        beatsPerBar: _config.beatsPerBar,
        patternSlots: _config.pattern.slots.map((s) => s.index).toList(),
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
    _control?.send(ConfigUpdate(
      next.bpm,
      next.beatsPerBar,
      next.pattern.slots.map((s) => s.index).toList(),
    ));
  }

  @override
  void dispose() => stop();
}
