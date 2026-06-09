/// Timing engine that delegates to native iOS/Android/macOS audio code.
///
/// The native side owns both scheduling and audio playback (AVAudioEngine on
/// iOS/macOS, AudioTrack on Android). Dart only receives beat callbacks for
/// UI updates via an EventChannel, so the Dart event-loop is entirely off the
/// critical audio path.
library;

import 'dart:async';

import 'package:flutter/services.dart';

import '../audio/timbre.dart';
import 'metronome_engine.dart';

const _methodChannel = MethodChannel('com.metronome.app/metronome');
const _eventChannel = EventChannel('com.metronome.app/metronome/beats');

class NativeMetronomeEngine implements MetronomeEngine {
  void Function(BeatEvent event) _onBeat;
  MetronomeConfig _config;
  String _timbreId = 'click';
  bool _running = false;
  StreamSubscription<dynamic>? _beatSub;

  NativeMetronomeEngine({
    required void Function(BeatEvent event) onBeat,
    MetronomeConfig config = const MetronomeConfig(),
  })  : _onBeat = onBeat,
        _config = config;

  @override
  set onBeatHandler(void Function(BeatEvent event) handler) => _onBeat = handler;

  @override
  bool get isRunning => _running;

  @override
  bool get handlesAudio => true;

  @override
  void start() {
    if (_running) return;
    _running = true;
    _beatSub = _eventChannel.receiveBroadcastStream().listen(_onNativeBeat);
    _methodChannel.invokeMethod<void>('start', _configArgs());
  }

  @override
  void stop() {
    if (!_running) return;
    _running = false;
    _beatSub?.cancel();
    _beatSub = null;
    _methodChannel.invokeMethod<void>('stop');
  }

  @override
  void updateConfig(MetronomeConfig config) {
    _config = config;
    if (_running) {
      _methodChannel.invokeMethod<void>('updateConfig', _configArgs());
    }
  }

  void setTimbre(Timbre t) {
    _timbreId = t.id;
    if (_running) {
      _methodChannel.invokeMethod<void>('setTimbre', {'timbreId': t.id});
    }
  }

  @override
  void dispose() => stop();

  Map<String, dynamic> _configArgs() => {
        'bpm': _config.bpm,
        'beatsPerBar': _config.beatsPerBar,
        'patternSlots': _config.pattern.slots.map((s) => s.index).toList(),
        'timbreId': _timbreId,
      };

  void _onNativeBeat(dynamic raw) {
    final map = (raw as Map).cast<String, dynamic>();
    final beatIndex = map['beatIndex'] as int;
    final slotIndex = map['slotIndex'] as int;
    final slotType = SlotType.values[map['slotType'] as int];
    _onBeat(BeatEvent(
      beatIndex: beatIndex,
      slotIndex: slotIndex,
      slotType: slotType,
      scheduledMicros: 0,
    ));
  }
}
