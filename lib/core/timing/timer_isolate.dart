/// 在独立 Isolate 中运行的计时核心。
///
/// 为什么放进 Isolate：主 isolate 上的 UI 重绘、动画、GC 都会抢占事件循环，
/// 让 Timer 回调延迟。把计时隔离出去，节拍就不受主线程卡顿影响。
///
/// 漂移处理沿用主实现的策略：理论拍点时间 `+= interval` 累加，
/// 而非基于「实际触发时刻」重置基准——后者会累积误差（参考项目的缺陷）。
library;

import 'dart:async';
import 'dart:isolate';

/// 启动 Isolate 时传入的初始化参数。
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

/// 主 → Isolate 的配置更新消息。
class ConfigUpdate {
  final int bpm;
  final int beatsPerBar;
  const ConfigUpdate(this.bpm, this.beatsPerBar);
}

/// Isolate → 主 的一次拍点消息。用普通 List 传输，跨 isolate 开销最小。
/// 格式: [beatIndex, isAccent(0/1), scheduledMicros]
typedef BeatMessage = List<int>;

const int _kTickMicros = 2000; // 每 2ms 检查一次是否到点

/// Isolate 入口。data 为 [TimerInit]。
void timerIsolateEntry(TimerInit init) {
  final control = ReceivePort();
  // 第一件事：把控制端口送回主 isolate，用于接收配置更新和停止信号。
  init.toMain.send(control.sendPort);

  int bpm = init.bpm;
  int beatsPerBar = init.beatsPerBar;

  int beatInterval() => (60 * 1000 * 1000) ~/ bpm;

  final clock = Stopwatch()..start(); // Isolate 内独占，无需可测试时钟
  int nextBeatMicros = 0;
  int nextBeatIndex = 0;

  Timer? ticker;

  void onTick(Timer _) {
    final now = clock.elapsedMicroseconds;
    while (now >= nextBeatMicros) {
      final isAccent = nextBeatIndex == 0;
      init.toMain.send(<int>[nextBeatIndex, isAccent ? 1 : 0, nextBeatMicros]);
      nextBeatMicros += beatInterval(); // 理论时间累加 —— 零漂移
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
