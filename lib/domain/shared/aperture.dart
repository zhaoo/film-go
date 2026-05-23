import 'package:meta/meta.dart';

/// 光圈值对象。
///
/// `fNumber` 是 f 数（如 2.8 表示 f/2.8）。整档序列见 [fullStops]。
@immutable
class Aperture {
  /// 主构造，f 值必须为正。
  Aperture(this.fNumber) : _displayOverride = null {
    if (fNumber <= 0) {
      throw ArgumentError.value(fNumber, 'fNumber', '必须为正数');
    }
  }

  /// 内部用：跳过校验的 const 构造，仅给 [fullStops] 这种编译期合法常量使用。
  ///
  /// [displayOverride] 可选，当设置后 [display] 直接返回该字符串，用于摄影惯例
  /// 渲染（如 √2 精确值 5.656... 期望显示成 `f/5.6` 而非 `f/5.7`）。
  const Aperture._unchecked(this.fNumber, [this._displayOverride]);

  final double fNumber;

  final String? _displayOverride;

  /// 摄影惯例显示，整数无小数（"f/8"），其他保留 1 位（"f/2.8"）。
  ///
  /// 若构造时传入了 [_displayOverride]，直接返回该字符串。
  String get display {
    if (_displayOverride != null) {
      return _displayOverride;
    }
    final s = fNumber == fNumber.roundToDouble()
        ? fNumber.toStringAsFixed(0)
        : fNumber.toStringAsFixed(1);
    return 'f/$s';
  }

  /// 标准整档序列（√2 等比），从 f/1 到 f/64 共 13 档。
  ///
  /// 摄影惯例显示为 f/1, 1.4, 2, 2.8, 4, 5.6, 8, 11, 16, 22, 32, 45, 64，
  /// 这里使用数学精确值（2^(n/2)），保证相邻比值严格等于 √2。
  static const List<Aperture> fullStops = <Aperture>[
    Aperture._unchecked(1.0),
    Aperture._unchecked(1.4142135623730951, 'f/1.4'), // √2
    Aperture._unchecked(2.0),
    Aperture._unchecked(2.8284271247461903, 'f/2.8'), // 2√2
    Aperture._unchecked(4.0),
    Aperture._unchecked(5.656854249492381, 'f/5.6'), // 4√2
    Aperture._unchecked(8.0),
    Aperture._unchecked(11.313708498984761, 'f/11'), // 8√2
    Aperture._unchecked(16.0),
    Aperture._unchecked(22.627416997969522, 'f/22'), // 16√2
    Aperture._unchecked(32.0),
    Aperture._unchecked(45.254833995939045, 'f/45'), // 32√2
    Aperture._unchecked(64.0),
  ];

  @override
  bool operator ==(Object other) =>
      other is Aperture && other.fNumber == fNumber;

  @override
  int get hashCode => fNumber.hashCode;
}
