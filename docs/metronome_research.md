# 开源节拍器应用实现调研报告

> 调研时间：2026-06-10  
> 调研方式：GitHub API 搜索 + Workflow 并行抓取分析（18 个 subagent，~3 小时）

---

## 1. 总览

调研覆盖 8 个开源节拍器项目，平台分布如下：

| 仓库 | 平台 | 技术栈 | Stars |
|------|------|--------|-------|
| [AlexShubin/Metronome](https://github.com/AlexShubin/Metronome) | iOS | Swift, AVAudioEngine, Swift Concurrency | 30 |
| [Alexander-Nagel/Metronome-using-AVAudioEngine](https://github.com/Alexander-Nagel/Metronome-using-AVAudioEngine) | iOS | Swift, AVAudioEngine, Foundation Timer | 9 |
| [depasca/GOTronome](https://github.com/depasca/GOTronome) | Android | Kotlin/Compose + Oboe C++ JNI | 10 |
| [gastonborba/metronome](https://github.com/gastonborba/metronome) | Android | Kotlin, AudioTrack MODE_STATIC | 2 |
| [josialfg/bitt-metronome](https://github.com/josialfg/bitt-metronome) | Android | Kotlin/Compose + Oboe C++ JNI | 0 |
| [Tyrone2333/metronomelutter](https://github.com/Tyrone2333/metronomelutter) | Flutter | Dart, audioplayers, MobX | 43 |
| [summerscar/metronome_flutter](https://github.com/summerscar/metronome_flutter) | Flutter | Dart, assets_audio_player | 9 |
| [scottwhudson/metronome](https://github.com/scottwhudson/metronome) | Web | JavaScript, Web Audio API, Web Worker | 62 |

---

## 2. 计时策略对比

| 仓库 | 计时方案 | 时钟来源 | Drift Correction | 质量评级 |
|------|----------|----------|-----------------|---------|
| AlexShubin/Metronome | 音频时钟轮询（无独立调度循环） | AVAudioPlayerNode.sampleTime | 结构性消除 | 优秀 |
| Alexander-Nagel | Foundation Timer（半周期预队列） | 系统壁钟 | 无 | 一般 |
| GOTronome | `frameCounter % samplesPerBeat`（音频回调内） | Oboe 音频采样时钟 | 结构性消除 | 优秀 |
| gastonborba/metronome | AudioTrack MODE_STATIC 无限循环 | 音频 HAL 硬件时钟 | 结构性消除 | 优秀 |
| bitt-metronome | `mTotalSamples >= mNextBeatSample`（Oboe 回调） | Oboe 音频采样时钟 | 加法累积，非重置 | 优秀 |
| Tyrone2333/metronomelutter | 递归单次 Dart Timer | 壁钟（事件循环） | 无 | 差 |
| summerscar/metronome_flutter | 递归单次 Dart Timer | 壁钟（事件循环） | 无 | 差 |
| scottwhudson/metronome | Web Worker + look-ahead scheduler | Web Audio API audioContext.currentTime | 加法累积，非重置 | 良好 |

**关键结论**：消除 drift 有两种路径：

- **路径 A（结构性消除）**：以音频硬件时钟为唯一时间源，完全不存在独立调度循环（AlexShubin、gastonborba、GOTronome）
- **路径 B（自校正累积）**：理论时间以 `+= interval` 前进而非重置为实际触发时刻（bitt-metronome、scottwhudson，以及我们的 `IsolateMetronomeEngine`）

---

## 3. 音频方案对比

### 3.1 AVAudioEngine（iOS/macOS）

代表项目：AlexShubin/Metronome、Alexander-Nagel

- 绕过 AVAudioSession 高延迟播放路径，使用 DSP 渲染线程
- `scheduleBuffer(at: AVAudioTime)` 支持样本级精确调度
- AlexShubin 方案：将整个小节烘焙为一个 PCM buffer 并循环，调度抖动只在启动时发生一次
- Alexander-Nagel 方案：使用 `at: nil`（队列相对时间），丧失了跨 tempo 变化的样本精确性

**核心差异**：`at: nil` vs `at: AVAudioTime` — 前者依赖引擎内部队列衔接，后者保证绝对时间戳。

### 3.2 Oboe（Android，C++ 实时线程）

代表项目：depasca/GOTronome、josialfg/bitt-metronome

- `PerformanceMode::LowLatency` + `SharingMode::Exclusive`：可获得设备最低可达延迟
- 高优先级实时线程，JVM GC 和 UI 绘制无法抢占
- bitt-metronome 使用 `std::atomic` 跨线程传参，完全无锁，避免优先级反转
- GOTronome 存在 `std::mutex`，有潜在延迟风险

### 3.3 AudioTrack PCM（Android）

代表项目：gastonborba/metronome（MODE_STATIC）；我们项目（流式，512 帧块）

| 维度 | MODE_STATIC（gastonborba） | 流式（我们的实现） |
|------|---------------------------|-----------------|
| 延迟 | 极低（HAL 在 play() 前已获得全部数据） | 低（512 帧 ≈ 约 11ms @44100Hz） |
| Tempo 变化 | 需 stop/restart，有短暂间隙 | 动态调整，无间隙 |
| Accent 支持 | 有限（均匀间距） | 完整（每拍可独立配置） |
| 内存 | 需完整小节缓冲区（低 BPM 时较大） | 固定大小流缓冲 |

### 3.4 Web Audio API（Web）

代表项目：scottwhudson/metronome

- `OscillatorNode.start(futureTime)` 在指定 `audioContext` 时间戳精确调度
- 每拍创建新的 `OscillatorNode` 对象，高 BPM 下 GC 压力较大
- look-ahead 缓冲确保即使主线程有抖动，音频也已提前排队
- 已知问题：OscillatorNode 产生正弦波，不是打击音头，对快节奏演奏感知不友好

### 3.5 audioplayers / assets_audio_player（Flutter 纯 Dart）

代表项目：Tyrone2333/metronomelutter、summerscar/metronome_flutter

- 经过 Dart → Platform Channel → 系统音频栈多层，延迟不可控
- `assets_audio_player` 每次 `open()` 触发实时解码，latency 可变
- **不适合节拍器级别的精度需求**

---

## 4. 架构模式对比

| 仓库 | 计时线程隔离 | 机制 | UI 通信 |
|------|------------|------|--------|
| AlexShubin/Metronome | 否（利用硬件时钟） | Swift Actor + AsyncStream | CADisplayLink 轮询 sampleTime |
| Alexander-Nagel | 否 | Foundation Timer（主线程） | DispatchQueue.main.async |
| GOTronome | 是 | Oboe 高优先级 C++ 线程 | JNI 回调 → StateFlow |
| gastonborba | 否 | 无调度循环（硬件驱动） | Android Service Intent |
| bitt-metronome | 是 | Oboe 高优先级 C++ 线程 | SPSC 环形缓冲 → JNI → SharedFlow |
| Tyrone2333/metronomelutter | 否 | Dart 主隔离 Timer | setState / MobX |
| summerscar/metronome_flutter | 否 | Dart 主隔离 Timer | setState |
| scottwhudson/metronome | 是（Web Worker） | setInterval 在 Worker | postMessage → 主线程调度 |

**bitt-metronome 的 SPSC 环形缓冲**：音频线程将视觉事件推入固定大小环形缓冲（`mVisualBuf[16]`），附带 `fireAtSample` 时间戳，彻底将 JNI 回调移出热路径：

```cpp
struct VisualEvent {
    int64_t fireAtSample;
    int     bar, beat, subIndex;
    bool    swapped;
};
// 音频线程写入，音频线程延迟读取后才触发 JNI
```

**AlexShubin 的 Actor + AsyncStream**：`Metronome` 是 Swift actor，通过 `AsyncStream<MetronomeState>` 向外流式推送状态，UI 层用 `for await` 消费。状态是 `Sendable` 值类型，无共享可变状态。

---

## 5. 节奏型支持

| 仓库 | 可配置拍号 | Subdivision | 自定义 Accent | Polyrhythm | 小节级模式切换 |
|------|-----------|-------------|--------------|-----------|--------------|
| AlexShubin/Metronome | 否（硬编码 4/4） | 否 | 否 | 否 | 否 |
| Alexander-Nagel | 否（硬编码 4/4） | 否 | 固定 beat 1 | 否 | 否 |
| GOTronome | 是（beatsPerMeasure） | 否 | 固定 beat 1 | 否 | 否（静音小节） |
| gastonborba | 是（beatsPerMeasure） | 否 | 否（均匀间距） | 否 | 否 |
| bitt-metronome | 是（2–6 拍） | 是（二分，非对称取整） | 是（0.5x gain） | 否 | 是（小节边界原子切换） |
| Tyrone2333/metronomelutter | 是 | 否 | 固定 beat 1 | 否 | 否 |
| summerscar/metronome_flutter | 否（硬编码 mod-4） | 否 | 固定 beat 1 | 否 | 否 |
| scottwhudson/metronome | 是 | 是（十二分音符网格） | 可独立开关音量 | 否 | 否 |

**scottwhudson 的十二分音符网格**：将全部细分统一为 12 细分/拍，用单一计数器覆盖所有情况：

```javascript
// 四分音符：每 12 个 twelvelet
// 八分音符：每 6 个 twelvelet
// 十六分音符：每 3 个 twelvelet
// 三连音：每 4 个 twelvelet
nextNoteTime += 0.08333 * secondsPerBeat; // 1/12 beat，加法累积
```

---

## 6. 代码片段亮点

### 6.1 AlexShubin：整小节 PCM Buffer 循环（iOS 结构性消除 drift）

```swift
func play(bpm: Double, clickSample: ClickSample) -> BarLength {
    let buffer = generateBuffer(bpm: bpm, clickSample: clickSample)
    audioPlayerNode.play()
    audioPlayerNode.scheduleBuffer(
        buffer,
        at: nil,
        options: [.interruptsAtLoop, .loops]  // 无缝循环，调度抖动只发生一次
    )
    return Double(buffer.frameLength)
}

// 拍位置从音频硬件时钟计算，不依赖任何软件计时器
var sampleTime: Double {
    guard let nodeTime = audioPlayerNode.lastRenderTime,
          let playerTime = audioPlayerNode.playerTime(forNodeTime: nodeTime) else {
        return 0
    }
    return Double(playerTime.sampleTime)
}

private func generateBuffer(bpm: Double, clickSample: ClickSample) -> AVAudioPCMBuffer {
    let beatLength = AVAudioFrameCount(AVAudioFormat.standard.sampleRate * 60 / bpm)
    let accentedClickSamples = readSamples(from: clickSample.accentedFile, beatLength: beatLength)
    let mainClickSamples = readSamples(from: clickSample.regularFile, beatLength: beatLength)
    var barSamples = accentedClickSamples
    for _ in 1...3 { barSamples.append(contentsOf: mainClickSamples) }
    let bufferBar = AVAudioPCMBuffer(pcmFormat: .standard, frameCapacity: 4 * beatLength)!
    bufferBar.frameLength = 4 * beatLength
    bufferBar.floatChannelData!.pointee.update(from: barSamples, count: Int(bufferBar.frameLength))
    return bufferBar
}
```

### 6.2 bitt-metronome：非对称细分取整防止整数舍入累积（Android C++）

```cpp
void onTickTriggered() {
    mClickGain = (mNextSubIndex == 0) ? 1.0f : 0.5f;

    if (subdivision == 2 && mNextSubIndex == 0) {
        // 前半拍：向下取整
        mNextSubIndex = 1;
        mNextBeatSample += samplesPerBeat / 2;
    } else {
        // 后半拍：取余数，消除舍入误差
        mNextSubIndex = 0;
        mNextBeatSample += (subdivision == 2)
            ? (samplesPerBeat - samplesPerBeat / 2)  // 精确余数，两次相加 == samplesPerBeat
            : samplesPerBeat;
        mCurrentBeat++;
    }
}
```

### 6.3 bitt-metronome：小节边界原子切换预设（无缝 Tempo/拍号过渡）

```cpp
if (mCurrentBeat >= beatsPerBar) {
    const bool canSwap = mHasPending.load() &&
        (endBar < 0 || mCurrentBar == endBar);
    if (canSwap) {
        // 在小节边界原子应用新预设，无音频断点
        mBpm.store(mPendingBpm.load());
        mBeatsPerBar.store(mPendingBeats.load());
        recomputeSamplesPerBeat();
        mCurrentBeat = 0;
        mCurrentBar  = 0;
    }
}
```

### 6.4 gastonborba：AudioTrack MODE_STATIC + 硬件无限循环（Android 最简方案）

```kotlin
fun start() {
    val buffer = generatePattern()
    audioTrack = AudioTrack.Builder()
        .setTransferMode(AudioTrack.MODE_STATIC)
        .build()
    audioTrack?.write(buffer, 0, buffer.size)
    audioTrack?.setLoopPoints(0, buffer.size, -1)  // 无限循环
    audioTrack?.play()
    // 之后不需要任何软件计时代码
}

private fun generatePattern(): ShortArray {
    val samplesPerBeat = (sampleRate * 60.0 / bpm).toInt()
    val buffer = ShortArray(samplesPerBeat * beatsPerMeasure) { 0 }
    for (beat in 0 until beatsPerMeasure) {
        val startIndex = beat * samplesPerBeat
        for (i in clickSample.indices) {
            if (startIndex + i < buffer.size) buffer[startIndex + i] = clickSample[i]
        }
    }
    return buffer
}
```

### 6.5 scottwhudson：Web Worker + look-ahead scheduler（Web 标准模式）

```javascript
// 主线程：look-ahead 调度器
function scheduler() {
    while (nextNoteTime < audioContext.currentTime + scheduleAheadTime) {
        scheduleNote(currentTwelveletNote, nextNoteTime);
        nextNoteTime += 0.08333 * secondsPerBeat;  // 加法累积，非重置
        currentTwelveletNote++;
    }
}

// worker.js：独立线程驱动 tick，不受主线程 GC/重绘影响
self.onmessage = function(e) {
    if (e.data == "start") {
        timerID = setInterval(() => postMessage("tick"), 25);
    } else if (e.data == "stop") {
        clearInterval(timerID);
    }
};
```

---

## 7. 对我们 Flutter 项目的启示

### 7.1 已验证正确的设计决策

以下调研中发现的最佳实践我们已采用：

- `IsolateMetronomeEngine` 的 `+= interval` 自校正调度 — 与 bitt-metronome 和 scottwhudson 的加法累积策略完全吻合
- 专用 Dart Isolate 隔离计时 — GOTronome 和 bitt-metronome 用 C++ 线程的理由同样适用
- NativeMetronomeEngine 委托给平台原生代码 — 被多个项目独立验证
- EventChannel push 回调而非 UI 轮询 — GOTronome 的轮询方式被其自身分析标记为反模式

### 7.2 可直接落地的改进点

**高优先级**

**1. 非对称细分取整**（潜在 bug，防整数舍入累积）

```dart
// 有隐患：
nextBeatTime += interval ~/ 2;
nextBeatTime += interval ~/ 2;  // 两次相加可能 != interval

// 修正：
nextBeatTime += interval ~/ 2;
nextBeatTime += interval - interval ~/ 2;  // 精确余数
```

**2. 小节边界参数切换**（演奏中调整 tempo/拍号无断点）

```dart
BeatParams? _pendingParams;
int _pendingAtBar = -1;  // -1 = 立即，N = 第 N 小节结束后生效

void scheduleParamChange(BeatParams params, {int atBar = -1}) {
    _pendingParams = params;
    _pendingAtBar = atBar;
}

void _onBarEnd(int currentBar) {
    if (_pendingParams != null &&
        (_pendingAtBar < 0 || currentBar == _pendingAtBar)) {
        _applyParams(_pendingParams!);
        _pendingParams = null;
    }
}
```

**3. 视觉延迟校准（Visual Offset Calibration）**

不同 Android 设备音频输出延迟差异可达 20–80ms。建议在设置页增加 ±100ms 可调偏移量，持久化到 `SettingsRepository`。

**中优先级**

**4. iOS 层整小节 PCM Buffer 循环** — 参考 AlexShubin，稳定 tempo 时将整小节烘焙为单一 buffer 以 `.loops` 循环，调度抖动归零。需参数化 `beatsPerBar` 和 accent pattern，而非硬编码 4/4。

**5. 屏幕常亮 Wakelock** — 确认计时运行时持有，否则屏幕关闭后 Dart Isolate 调度可能被系统节流。

**6. FLAC 加载失败正弦波兜底** — 特定设备 MediaCodec 异常时降级到合成点击声，确保应用在任何设备上都能发出声音。

**低优先级**

**7. 静音练习模式** — 每 N 小节静音一小节（GOTronome 已实现），音频流不中断，时钟不停，仅将对应样本位置置零。

### 7.3 应避免的反模式

| 反模式 | 来源 | 我们的规避方式 |
|--------|------|--------------|
| 递归单次 Timer，无 drift 校正 | summerscar、Tyrone2333 | IsolateMetronomeEngine `+= interval` |
| 计时与 UI 共用主线程/Isolate | summerscar、Tyrone2333 | 专用 Dart Isolate |
| 每拍实时解码音频资源 | summerscar | 预加载 FLAC，AudioTrack PCM |
| 音频回调内使用 mutex | GOTronome | 应使用 `std::atomic`（需检查我们的 Kotlin 层） |
| UI 轮询当前拍位置 | GOTronome | EventChannel push 回调 |
| `at: nil` 队列相对时间调度 | Alexander-Nagel | `at: AVAudioTime` 绝对时间戳调度 |

---

**总结**：调研的 8 个项目中，计时质量两极分化明显——纯 Dart Timer 方案全部存在 drift 问题，原生音频硬件时钟方案在结构上消除了 drift。我们项目的架构决策与行业最优实践一致。**最值得优先落地的是非对称细分取整（潜在 bug）和小节边界参数切换（专业场景体验提升）。**
