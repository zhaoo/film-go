import 'dart:math' as math;

import 'package:film_go/domain/shared/iso_value.dart';

/// 反射光亮度（0..255 灰度均值）→ EV 换算。
///
/// 公式（反射光测光基线）：
///   EV = log2(L_norm · K) + log2(ISO/100) + offset
/// 其中 L_norm = grayMean/255，K=12.5（CIPA / ISO 2720 反射光常数）。
/// `calibrationOffset` 由用户在已知 EV 场景下校准得出。
class LuminanceToEv {
  const LuminanceToEv._();

  /// K：反射光常数（CIPA / ISO 2720）。
  static const double k = 12.5;

  /// 防止 grayMean=0 时 log2 = -∞ 的下界。
  static const double _grayFloor = 0.5;

  static double fromGrayMean({
    required num grayMean,
    required IsoValue iso,
    required double calibrationOffset,
  }) {
    final clamped = grayMean < _grayFloor ? _grayFloor : grayMean.toDouble();
    final lNorm = clamped / 255.0;
    final base = math.log(lNorm * k) / math.ln2;
    final isoTerm = math.log(iso.value / 100) / math.ln2;
    return base + isoTerm + calibrationOffset;
  }

  /// 反推：给定 grayMean/ISO 与"参考 EV"，返回需要的偏移使结果落在 targetEv。
  static double calibrationOffsetFor({
    required num grayMean,
    required IsoValue iso,
    required double targetEv,
  }) {
    final raw = fromGrayMean(
      grayMean: grayMean,
      iso: iso,
      calibrationOffset: 0,
    );
    return targetEv - raw;
  }

  /// 入射光测光常数（CIPA / ISO 2720）。
  static const double cIncident = 2.5;

  /// 防止 lux=0 的 floor。
  static const double _luxFloor = 0.01;

  /// EV (入射光) = log2(lux / C) + log2(ISO/100) + offset
  static double fromLux({
    required num lux,
    required IsoValue iso,
    required double calibrationOffset,
  }) {
    final clamped = lux < _luxFloor ? _luxFloor : lux.toDouble();
    final base = math.log(clamped / cIncident) / math.ln2;
    final isoTerm = math.log(iso.value / 100) / math.ln2;
    return base + isoTerm + calibrationOffset;
  }
}
