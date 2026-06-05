/// The timing core that runs inside a dedicated Isolate.
///
/// Why an Isolate: UI repaints, animations, and GC on the main isolate all
/// preempt the event loop and delay Timer callbacks. Isolating the timing keeps
/// the beat unaffected by main-thread stalls.
///
/// Drift handling matches the main implementation: the theoretical beat time
/// advances by `+= interval`, rather than resetting the baseline to the actual
/// fire time (the latter accumulates error — a flaw in the reference project).
library;

import 'dart:async';
import 'dart:isolate';

/// Initialization parameters passed when spawning the Isolate.
class TimerInit {
  final SendPort toMain;
  final int bpm;
  final int beatsPerBar;

  const TimerInit({
    required this.toMain,
    required this.bpm,
    required this.beatsPerBar,
  });
}

/// Main → Isolate config update message.
class ConfigUpdate {
  final int bpm;
  final int beatsPerBar;
  const ConfigUpdate(this.bpm, this.beatsPerBar);
}

/// Isolate → main beat message. Sent as a plain List to minimize cross-isolate
/// overhead. Format: [beatIndex, isAccent(0/1), scheduledMicros]
typedef BeatMessage = List<int>;

const int _kTickMicros = 2000; // check whether it's time every 2ms

/// Isolate entry point. `data` is a [TimerInit].
void timerIsolateEntry(TimerInit init) {
  final control = ReceivePort();
  // First thing: send the control port back to the main isolate so it can
  // receive config updates and the stop signal.
  init.toMain.send(control.sendPort);

  int bpm = init.bpm;
  int beatsPerBar = init.beatsPerBar;

  int beatInterval() => (60 * 1000 * 1000) ~/ bpm;

  final clock = Stopwatch()..start(); // isolate-local; no need for a test clock
  int nextBeatMicros = 0;
  int nextBeatIndex = 0;

  Timer? ticker;

  void onTick(Timer _) {
    final now = clock.elapsedMicroseconds;
    while (now >= nextBeatMicros) {
      final isAccent = nextBeatIndex == 0;
      init.toMain.send(<int>[nextBeatIndex, isAccent ? 1 : 0, nextBeatMicros]);
      nextBeatMicros += beatInterval(); // theoretical time advances — no drift
      nextBeatIndex = (nextBeatIndex + 1) % beatsPerBar;
    }
  }

  control.listen((msg) {
    if (msg is ConfigUpdate) {
      bpm = msg.bpm;
      if (nextBeatIndex >= msg.beatsPerBar) nextBeatIndex = 0;
      beatsPerBar = msg.beatsPerBar;
    } else if (msg == 'stop') {
      ticker?.cancel();
      control.close();
    }
  });

  ticker = Timer.periodic(const Duration(microseconds: _kTickMicros), onTick);
}
