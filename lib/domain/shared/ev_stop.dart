import 'package:meta/meta.dart';

/// 1/3 stop 步长的 EV 档位值对象。
///
/// 范围 ±3 stop = ±9 thirds，共 19 档（含 0）。用于 EV 补偿、相对偏移等
/// 不需要小数的语义场景。Display 使用摄影圈惯例的分数写法
/// （`+1/3`、`-2/3`、`+1 1/3` 等）。
@immutable
class EvStop {
  const EvStop._(this.thirds);

  /// 以"几个 1/3 stop"构造，超出 ±9 抛 [ArgumentError]。
  factory EvStop.thirds(int thirds) {
    if (thirds < minThirds || thirds > maxThirds) {
      throw ArgumentError.value(
        thirds,
        'thirds',
        '超出 EvStop 范围 [$minThirds, $maxThirds]',
      );
    }
    return EvStop._(thirds);
  }

  static const int minThirds = -9;
  static const int maxThirds = 9;

  static const EvStop zero = EvStop._(0);

  final int thirds;

  /// 以 stop 为单位的连续值（每 thirds = 1/3 stop）。
  double get stops => thirds / 3.0;

  /// 加法，越界时夹到 ±9。
  EvStop operator +(EvStop other) {
    final sum = (thirds + other.thirds).clamp(minThirds, maxThirds);
    return EvStop._(sum);
  }

  /// 全部 19 档，自 -3 到 +3。
  static List<EvStop> get values =>
      List.unmodifiable(<EvStop>[
        for (var t = minThirds; t <= maxThirds; t++) EvStop._(t),
      ]);

  String get display {
    if (thirds == 0) return '0';
    final sign = thirds > 0 ? '+' : '-';
    final abs = thirds.abs();
    final whole = abs ~/ 3;
    final rem = abs % 3;
    if (rem == 0) return '$sign$whole';
    final frac = rem == 1 ? '1/3' : '2/3';
    if (whole == 0) return '$sign$frac';
    return '$sign$whole $frac';
  }

  @override
  bool operator ==(Object other) => other is EvStop && other.thirds == thirds;

  @override
  int get hashCode => thirds.hashCode;
}
