/// 基于 Isolate 的计时引擎实现（生产用）。
///
/// 计时跑在独立 Isolate（见 [timer_isolate.dart]），主线程的 UI 重绘、动画、
/// GC 都不会干扰节拍。拍点通过 SendPort 回传主 isolate 后再发声与刷 UI。
library;

// 构造函数有意用命名参数 + 初始化列表（字段私有），可读性更好。
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
  SendPort? _control; // 向 Isolate 发配置更新 / 停止

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
    // 异步拉起 Isolate；start() 本身保持同步签名以契合接口。
    unawaited(_spawn());
  }

  Future<void> _spawn() async {
    final fromIsolate = ReceivePort();
    _fromIsolate = fromIsolate;

    _sub = fromIsolate.listen((msg) {
      if (msg is SendPort) {
        _control = msg; // Isolate 回传的控制端口
      } else if (msg is List) {
        // 拍点消息: [beatIndex, isAccent, scheduledMicros]
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
