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

  @override
  bool operator ==(Object other) => other is IsoValue && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
