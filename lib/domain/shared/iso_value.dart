import 'package:meta/meta.dart';

/// 胶卷或数字传感器的 ISO 感光度。
@immutable
class IsoValue {
  IsoValue(this.value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', '必须为正数');
    }
  }

  /// 内部用：跳过校验的 const 构造，仅给 [fullStops] 这种编译期合法常量使用。
  const IsoValue._unchecked(this.value);

  final int value;

  String get display => 'ISO $value';

  /// 标准整档 ISO 序列（每相邻两值比为 2）。
  static const List<IsoValue> fullStops = <IsoValue>[
    IsoValue._unchecked(25),
    IsoValue._unchecked(50),
    IsoValue._unchecked(100),
    IsoValue._unchecked(200),
    IsoValue._unchecked(400),
    IsoValue._unchecked(800),
    IsoValue._unchecked(1600),
    IsoValue._unchecked(3200),
    IsoValue._unchecked(6400),
  ];

  /// 1/3 stop ISO 序列，覆盖 25..6400 共 25 档。
  ///
  /// 数值取摄影界惯用的近似（见 ISO 12232 / Sekonic 测光表）；
  /// 测试中只断言相邻 ratio ≈ 2^(1/3) ± 6%。
  static const List<IsoValue> thirdStops = <IsoValue>[
    IsoValue._unchecked(25),
    IsoValue._unchecked(32),
    IsoValue._unchecked(40),
    IsoValue._unchecked(50),
    IsoValue._unchecked(64),
    IsoValue._unchecked(80),
    IsoValue._unchecked(100),
    IsoValue._unchecked(125),
    IsoValue._unchecked(160),
    IsoValue._unchecked(200),
    IsoValue._unchecked(250),
    IsoValue._unchecked(320),
    IsoValue._unchecked(400),
    IsoValue._unchecked(500),
    IsoValue._unchecked(640),
    IsoValue._unchecked(800),
    IsoValue._unchecked(1000),
    IsoValue._unchecked(1250),
    IsoValue._unchecked(1600),
    IsoValue._unchecked(2000),
    IsoValue._unchecked(2500),
    IsoValue._unchecked(3200),
    IsoValue._unchecked(4000),
    IsoValue._unchecked(5000),
    IsoValue._unchecked(6400),
  ];

  @override
  bool operator ==(Object other) => other is IsoValue && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
