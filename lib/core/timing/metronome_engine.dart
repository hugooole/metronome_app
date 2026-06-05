/// 节拍器计时引擎 —— 公共类型与抽象接口。
///
/// 核心设计：自校正调度，消除累积漂移。
///   维护「理论拍点时间」每拍 `+= interval`，而非基于实际触发时刻重置基准。
///   即使某次检查晚了几毫秒，下一拍的理论时间不受影响，误差不累积。
///
/// 两个实现：
///   - [LocalMetronomeEngine]：同进程，用可注入时钟，便于 fakeAsync 精确测试。
///   - [IsolateMetronomeEngine]：独立 Isolate，主线程卡顿不影响节拍，用于生产。
library;

/// 一次拍点事件。
class BeatEvent {
  /// 0-based，当前是小节内第几拍。
  final int beatIndex;

  /// 是否为强拍（小节第一拍）。
  final bool isAccent;

  /// 该拍的理论触发时刻（相对引擎启动的微秒数），用于精度测量。
  final int scheduledMicros;

  const BeatEvent({
    required this.beatIndex,
    required this.isAccent,
    required this.scheduledMicros,
  });
}

/// 计时引擎配置。所有字段不可变，改参数请用 [copyWith] 生成新实例。
class MetronomeConfig {
  final int bpm;
  final int beatsPerBar;

  const MetronomeConfig({this.bpm = 120, this.beatsPerBar = 4});

  /// 一拍的时长（微秒）。
  int get beatIntervalMicros => (60 * 1000 * 1000) ~/ bpm;

  MetronomeConfig copyWith({int? bpm, int? beatsPerBar}) => MetronomeConfig(
        bpm: bpm ?? this.bpm,
        beatsPerBar: beatsPerBar ?? this.beatsPerBar,
      );
}

/// 计时引擎抽象接口。状态层只依赖它，可在测试/生产间切换实现。
abstract class MetronomeEngine {
  /// 拍点回调。可在构造后替换。
  set onBeatHandler(void Function(BeatEvent event) handler);

  bool get isRunning;

  void start();
  void stop();

  /// 运行中更新配置（BPM / 拍号）。
  void updateConfig(MetronomeConfig config);

  void dispose();
}
