/// 节拍器发声层。
///
/// 对外暴露 [ClickPlayer] 抽象接口，状态层只依赖接口，不依赖 flutter_soloud。
/// 好处：测试可注入假播放器；将来换音频库只改实现，不动上层。
library;

import 'package:flutter_soloud/flutter_soloud.dart';

/// 节拍器发声接口。
abstract class ClickPlayer {
  /// 加载音频资源，必须在播放前调用一次。
  Future<void> init();

  /// 播放强拍（小节第一拍）。
  void playAccent();

  /// 播放弱拍。
  void playNormal();

  /// 释放资源。
  void dispose();
}

/// 基于 flutter_soloud 的实现。
///
/// 设计要点：
/// - 只用一个 click 源（用户提供的 unfa 2kHz 脉冲，FLAC，约 50ms）。
/// - 强拍/弱拍不靠两个素材文件，而靠**音量 + 播放速度（音高）**区分：
///   强拍原速、满音量；弱拍提速（音调更高更短促）、略降音量。
///   这样单文件即可清晰区分小节，避免素材不匹配。
/// - click 很短，预加载为内存音源，播放零磁盘 IO，延迟最低。
/// - 每次播放都是一次性 oneshot，不复用 handle，避免相互打断。
class SoLoudClickPlayer implements ClickPlayer {
  static const String _clickAsset = 'assets/sounds/click.flac';

  // 强弱拍的音量与音高（相对播放速度）差异。
  static const double _accentVolume = 1.0;
  static const double _normalVolume = 0.6;
  static const double _accentSpeed = 1.0;
  static const double _normalSpeed = 1.5; // 弱拍音调更高，听感更"轻"

  final SoLoud _soloud = SoLoud.instance;

  AudioSource? _click;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (!_soloud.isInitialized) {
      await _soloud.init();
    }
    _click = await _soloud.loadAsset(_clickAsset);
    _ready = true;
  }

  @override
  void playAccent() => _playClick(_accentVolume, _accentSpeed);

  @override
  void playNormal() => _playClick(_normalVolume, _normalSpeed);

  void _playClick(double volume, double speed) {
    final src = _click;
    if (!_ready || src == null) return;
    // 先 paused 播放以便设置参数，再恢复——保证音量/音高在发声前生效。
    final handle = _soloud.play(src, volume: volume, paused: true);
    _soloud.setRelativePlaySpeed(handle, speed);
    _soloud.setPause(handle, false);
  }

  @override
  void dispose() {
    final src = _click;
    if (src != null) _soloud.disposeSource(src);
    _click = null;
    _ready = false;
  }
}
