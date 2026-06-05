/// 同进程计时引擎实现。
///
/// 用 `package:clock` 的可注入时钟（而非 Stopwatch），使 fakeAsync 能接管时间，
/// 从而对零漂移调度做精确单元测试。生产环境用 [IsolateMetronomeEngine]。
library;

// 构造函数有意用命名参数 + 初始化列表（字段私有），可读性更好。
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:clock/clock.dart';

import 'metronome_engine.dart';

class LocalMetronomeEngine implements MetronomeEngine {
  /// 检查间隔。远小于拍间隔，保证「到点」判断足够及时。
  static const Duration _tickInterval = Duration(milliseconds: 5);

  void Function(BeatEvent event) _onBeat;
  MetronomeConfig _config;

  Timer? _ticker;
  DateTime? _startTime;
  int _nextBeatMicros = 0;
  int _nextBeatIndex = 0;

  LocalMetronomeEngine({
    required void Function(BeatEvent event) onBeat,
    MetronomeConfig config = const MetronomeConfig(),
  })  : _onBeat = onBeat,
        _config = config;

  @override
  set onBeatHandler(void Function(BeatEvent event) handler) =>
      _onBeat = handler;

  @override
  bool get isRunning => _ticker != null;

  @override
  void start() {
    if (isRunning) return;
    _startTime = clock.now();
    _nextBeatMicros = 0; // 第一拍立即发声
    _nextBeatIndex = 0;
    _ticker = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  @override
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _startTime = null;
  }

  @override
  void updateConfig(MetronomeConfig next) {
    _config = next;
    if (_nextBeatIndex >= next.beatsPerBar) {
      _nextBeatIndex = 0;
    }
  }

  void _onTick() {
    final startTime = _startTime;
    if (startTime == null) return;

    final now = clock.now().difference(startTime).inMicroseconds;

    // 一次 tick 内可能要补发多拍（极高 BPM 或主线程卡顿时）。
    while (now >= _nextBeatMicros) {
      final beatIndex = _nextBeatIndex;
      _onBeat(BeatEvent(
        beatIndex: beatIndex,
        isAccent: beatIndex == 0,
        scheduledMicros: _nextBeatMicros,
      ));
      // 理论时间按拍间隔累加 —— 漂移在此处被消除。
      _nextBeatMicros += _config.beatIntervalMicros;
      _nextBeatIndex = (beatIndex + 1) % _config.beatsPerBar;
    }
  }

  @override
  void dispose() => stop();
}
