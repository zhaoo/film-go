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

  /// 仅供 [fullStops] 这类编译期合法常量使用，跳过运行时校验。
  /// `assert` 仅在 debug 模式生效，作为编译期 ladder 数据的最后兜底。
  const ShutterSpeed._unchecked(this.seconds) : assert(seconds > 0);

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

  /// 摄影惯例的整档快门序列，慢→快共 19 档。
  ///
  /// 1/15s 后保持 1, 2, 4, 8... 的传统分母（1/30 → 1/60 等），符合相机
  /// 转盘刻度，便于 EvCalculator 把理论值吸附到这里。
  static const List<ShutterSpeed> fullStops = <ShutterSpeed>[
    ShutterSpeed._unchecked(30),
    ShutterSpeed._unchecked(15),
    ShutterSpeed._unchecked(8),
    ShutterSpeed._unchecked(4),
    ShutterSpeed._unchecked(2),
    ShutterSpeed._unchecked(1),
    ShutterSpeed._unchecked(1 / 2),
    ShutterSpeed._unchecked(1 / 4),
    ShutterSpeed._unchecked(1 / 8),
    ShutterSpeed._unchecked(1 / 15),
    ShutterSpeed._unchecked(1 / 30),
    ShutterSpeed._unchecked(1 / 60),
    ShutterSpeed._unchecked(1 / 125),
    ShutterSpeed._unchecked(1 / 250),
    ShutterSpeed._unchecked(1 / 500),
    ShutterSpeed._unchecked(1 / 1000),
    ShutterSpeed._unchecked(1 / 2000),
    ShutterSpeed._unchecked(1 / 4000),
    ShutterSpeed._unchecked(1 / 8000),
  ];

  @override
  bool operator ==(Object other) =>
      other is ShutterSpeed && other.seconds == seconds;

  @override
  int get hashCode => seconds.hashCode;
}
