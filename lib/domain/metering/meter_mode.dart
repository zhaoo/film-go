/// 测光模式。
enum MeterMode {
  /// 点测：以指定中心点为中心、边长为短边 5% 的方形均值。
  spot,

  /// 中央重点：中心 25% 区域均值 × 0.75 + 整帧均值 × 0.25。
  centerWeighted,

  /// 平均：整帧均值。
  average;

  String get display => switch (this) {
        MeterMode.spot => '点测',
        MeterMode.centerWeighted => '中央重点',
        MeterMode.average => '平均',
      };
}
