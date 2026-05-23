import 'package:meta/meta.dart';

/// 快门速度值对象。
@immutable
class ShutterSpeed {
  /// 以秒为单位构造。`seconds` 必须为正。
  ShutterSpeed.seconds(this.seconds) {
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds', '必须为正数');
    }
  }

  final double seconds;

  /// ≥1 秒：整数 `30s`，非整数 `1.5s`；<1 秒：`1/250`（取最近整数分母）。
  String get display {
    if (seconds >= 1) {
      if (seconds == seconds.roundToDouble()) {
        return '${seconds.toStringAsFixed(0)}s';
      }
      return '${seconds.toStringAsFixed(1)}s';
    }
    final denom = (1 / seconds).round();
    return '1/$denom';
  }

  @override
  bool operator ==(Object other) =>
      other is ShutterSpeed && other.seconds == seconds;

  @override
  int get hashCode => seconds.hashCode;
}
