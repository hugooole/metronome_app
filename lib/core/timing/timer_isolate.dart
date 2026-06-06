/// The timing core that runs inside a dedicated Isolate.
library;

import 'dart:async';
import 'dart:isolate';

import 'rhythm_pattern.dart';

/// Initialization parameters passed when spawning the Isolate.
class TimerInit {
  final SendPort toMain;
  final int bpm;
  final int beatsPerBar;
  final List<int> patternSlots; // SlotType indices, variable length (3 or 4)

  const TimerInit({
    required this.toMain,
    required this.bpm,
    required this.beatsPerBar,
    required this.patternSlots,
  });
}

/// Main → Isolate config update message.
class ConfigUpdate {
  final int bpm;
  final int beatsPerBar;
  final List<int> patternSlots;
  const ConfigUpdate(this.bpm, this.beatsPerBar, this.patternSlots);
}

const int _kTickMicros = 2000;

void timerIsolateEntry(TimerInit init) {
  final control = ReceivePort();
  init.toMain.send(control.sendPort);

  int bpm = init.bpm;
  int beatsPerBar = init.beatsPerBar;
  List<int> patternSlots = init.patternSlots;

  int beatInterval() => (60 * 1000 * 1000) ~/ bpm;

  final clock = Stopwatch()..start();
  int beatStartMicros = 0;
  int nextBeatIndex = 0;
  int nextSlotIndex = 0;

  int nextSlotMicros() =>
      beatStartMicros + nextSlotIndex * beatInterval() ~/ patternSlots.length;

  void onTick(Timer _) {
    final now = clock.elapsedMicroseconds;
    while (now >= nextSlotMicros()) {
      final beatIndex = nextBeatIndex;
      final slotIndex = nextSlotIndex;
      final scheduledMicros = nextSlotMicros();
      final raw = SlotType.values[patternSlots[slotIndex]];
      final slotType = (beatIndex == 0 && slotIndex == 0)
          ? (raw == SlotType.rest ? SlotType.rest : SlotType.accent)
          : (raw == SlotType.accent ? SlotType.normal : raw);

      if (slotType != SlotType.rest) {
        init.toMain.send(<int>[
          beatIndex,
          slotIndex,
          slotType.index,
          scheduledMicros,
        ]);
      }

      nextSlotIndex++;
      if (nextSlotIndex >= patternSlots.length) {
        nextSlotIndex = 0;
        // Beat boundary advances by exactly beatIntervalMicros — zero drift.
        beatStartMicros += beatInterval();
        nextBeatIndex = (nextBeatIndex + 1) % beatsPerBar;
      }
    }
  }

  control.listen((msg) {
    if (msg is ConfigUpdate) {
      bpm = msg.bpm;
      if (nextBeatIndex >= msg.beatsPerBar) nextBeatIndex = 0;
      beatsPerBar = msg.beatsPerBar;
      patternSlots = msg.patternSlots;
    } else if (msg == 'stop') {
      control.close();
    }
  });

  Timer.periodic(const Duration(microseconds: _kTickMicros), onTick);
}
