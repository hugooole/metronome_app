/// Tap Tempo: derive BPM from repeated taps.
///
/// Pure logic, no UI dependency, easy to test.
/// Algorithm: record the most recent tap times and convert the average of
/// adjacent intervals into BPM. If no tap occurs within [resetGap], start a new
/// group.
library;

const int _kMinBpm = 30;
const int _kMaxBpm = 300;

class TapTempoCalculator {
  /// Max number of intervals to average (the most recent ones, more responsive).
  final int maxIntervals;

  /// Reset if two taps are farther apart than this.
  final Duration resetGap;

  final List<DateTime> _taps = [];

  TapTempoCalculator({
    this.maxIntervals = 4,
    this.resetGap = const Duration(seconds: 2),
  });

  /// Record a tap and return the current BPM estimate; null if fewer than two
  /// taps.
  int? tap(DateTime now) {
    if (_taps.isNotEmpty && now.difference(_taps.last) > resetGap) {
      _taps.clear();
    }
    _taps.add(now);

    // Keep only the most recent maxIntervals+1 timestamps.
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
