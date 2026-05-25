/// 胶卷画幅及对应弥散圆 c 值（mm）。
///
/// c 取自常用工程经验：35mm 民用 0.030mm；中画幅按对角线比例近似；
/// 4×5 取大画幅常用 0.150mm。详见 spec §3.2。
enum FilmFormat {
  f135(label: '135', cocMm: 0.030),
  f6x6(label: '6×6', cocMm: 0.060),
  f6x7(label: '6×7', cocMm: 0.066),
  f4x5(label: '4×5', cocMm: 0.150);

  const FilmFormat({required this.label, required this.cocMm});

  final String label;
  final double cocMm;
}
