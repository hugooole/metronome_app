/// Tap Tempo：连续敲击算出 BPM。
///
/// 纯逻辑，无 UI 依赖，便于测试。
/// 算法：记录最近若干次敲击时刻，取相邻间隔的平均值换算 BPM。
/// 超过 [resetGap] 没敲，视为重新开始一组。
library;

const int _kMinBpm = 30;
const int _kMaxBpm = 300;

class TapTempoCalculator {
  /// 最多参与平均的间隔数（取最近的几次，更跟手）。
  final int maxIntervals;

  /// 两次敲击超过此间隔则重置。
  final Duration resetGap;

  final List<DateTime> _taps = [];

  TapTempoCalculator({
    this.maxIntervals = 4,
    this.resetGap = const Duration(seconds: 2),
  });

  /// 记录一次敲击，返回当前估算的 BPM；不足两次返回 null。
  int? tap(DateTime now) {
    if (_taps.isNotEmpty && now.difference(_taps.last) > resetGap) {
      _taps.clear();
    }
    _taps.add(now);

    // 只保留最近 maxIntervals+1 个时刻。
    while (_taps.length > maxIntervals + 1) {
      _taps.removeAt(0);
    }

    if (_taps.length < 2) return null;

    var totalMicros = 0;
    for (var i = 1; i < _taps.length; i++) {
      totalMicros += _taps[i].difference(_taps[i - 1]).inMicroseconds;
    }
    final avgMicros = totalMicros / (_taps.length - 1);
    if (avgMicros <= 0) return null;

    final bpm = (60 * 1000 * 1000 / avgMicros).round();
    return bpm.clamp(_kMinBpm, _kMaxBpm);
  }

  void reset() => _taps.clear();
}
