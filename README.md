# 节拍器 (Metronome)

一个用 Flutter 编写的跨平台节拍器练习 app，专注于**计时精度**。

## 功能

- **BPM 调节**：30–300，滑块 + ±1 / ±5 微调
- **拍号**：2/4、3/4、4/4、6/8
- **强弱拍重音**：每小节第一拍区分音色
- **Tap Tempo**：连续敲击自动测算 BPM
- **拍点视觉指示**：实时高亮当前拍，强拍突出
- **设置记忆**：自动恢复上次的 BPM 与拍号

## 设计要点

### 零漂移计时

节拍器的核心难点是计时精度。本项目**不**在定时器回调里直接发声（抖动大），而是采用**自校正调度**：维护「理论拍点时间」按 `+= interval` 累加，而非基于实际触发时刻重置基准。即使某次检查晚了几毫秒，下一拍的理论时间不受影响，误差不累积。

实测：120 BPM 跑 23 拍，总漂移仅 -2.31ms，单拍抖动 ≤2.23ms（含 Isolate→主线程通信开销）。

### Isolate 隔离

计时跑在独立 Isolate 中，主线程的 UI 重绘、动画、GC 不会干扰节拍。计时层做成抽象接口 + 双实现：

- `LocalMetronomeEngine`：同进程，用可注入时钟，便于 `fakeAsync` 精确单测
- `IsolateMetronomeEngine`：独立 Isolate，生产环境使用

## 项目结构

```
lib/
├── main.dart                          入口，依赖注入
├── core/
│   ├── timing/
│   │   ├── metronome_engine.dart      抽象接口 + BeatEvent/MetronomeConfig
│   │   ├── local_metronome_engine.dart 同进程实现（可测试）
│   │   ├── isolate_metronome_engine.dart Isolate 实现（生产）
│   │   └── timer_isolate.dart         Isolate 内的计时核心
│   └── audio/click_player.dart        SoLoud 发声层
├── features/metronome/
│   ├── state/
│   │   ├── metronome_controller.dart  状态粘合层（ChangeNotifier）
│   │   └── tap_tempo.dart             Tap Tempo 算法
│   └── ui/                            界面与组件
└── data/settings_repository.dart      设置持久化
```

## 技术栈

- Flutter 3.44.1 / Dart 3.12.1
- [flutter_soloud](https://pub.dev/packages/flutter_soloud) — 低延迟音频
- [shared_preferences](https://pub.dev/packages/shared_preferences) — 设置持久化
- [clock](https://pub.dev/packages/clock) — 可注入时钟（测试用）

## 开发

```bash
flutter pub get
flutter test          # 运行全部测试
flutter run           # 在连接的设备/模拟器上运行
```

## 致谢

click 音效来自 [unfa](https://freesound.org/)（Freesound）。计时方案的 Isolate 隔离思路参考了 [reliable_interval_timer](https://github.com/inf0rmatix/reliable_interval_timer)。
