import 'dart:math' as math;

import 'package:film_go/domain/shared/iso_value.dart';

/// 反射光亮度（0..255 灰度均值）→ EV 换算。
///
/// 旧 API（[fromGrayMean] / [calibrationOffsetFor]）保留以兼容当前 controller，
/// 新公式见 [fromCameraFrame]：使用相机自报的 N/t/sensorIso + sRGB 反 gamma 后的
/// 线性灰度 yLinear 计算 EV100，不再依赖 K=12.5 + ISO 这种"中灰假设"。
class LuminanceToEv {
  const LuminanceToEv._();

  /// K：反射光常数（CIPA / ISO 2720）。
  static const double k = 12.5;

  /// 18% 中灰参考。
  static const double midGrayLinear = 0.18;

  /// 防止 grayMean=0 时 log2 = -∞ 的下界。
  static const double _grayFloor = 0.5;

  /// 防止 yLinear=0 的 floor（线性域）。取得足够小，让黑场也能给出 -8 EV 左右。
  static const double _yLinearFloor = 1e-6;

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

  /// 用相机自报曝光参数 + 该帧 ROI 的归一化线性灰度 yLinear（0..1）算 EV100。
  ///
  /// 推导：相机让 ROI 看起来是 yLinear（相对中灰 0.18）；如果以 (N, t, sensorIso)
  /// 拍它，对应到 ISO 100 上的 EV 是：
  ///
  ///   EV100 = log2(N² / t) − log2(sensorIso/100) + log2(yLinear / 0.18)
  ///         + calibrationOffset
  ///
  /// 物理意义：第一项是"这台相机此帧实际给 ROI 的曝光"；第二项把它换算到 ISO 100；
  /// 第三项把 ROI 亮度从中灰修正到真实场景亮度——比中灰亮 +1 stop。
  static double fromCameraFrame({
    required double aperture,
    required double exposureSec,
    required int sensorIso,
    required double yLinear,
    required double calibrationOffset,
  }) {
    final t = exposureSec <= 0 ? 1e-9 : exposureSec;
    final n = aperture <= 0 ? 1e-9 : aperture;
    final iso = sensorIso <= 0 ? 1 : sensorIso;
    final y = yLinear < _yLinearFloor ? _yLinearFloor : yLinear;
    final shutterTerm = math.log((n * n) / t) / math.ln2;
    final isoTerm = math.log(iso / 100) / math.ln2;
    final yTerm = math.log(y / midGrayLinear) / math.ln2;
    return shutterTerm - isoTerm + yTerm + calibrationOffset;
  }

  /// 反推：给定相机帧 + 目标 EV，得出 calibrationOffset。
  static double calibrationOffsetForFrame({
    required double aperture,
    required double exposureSec,
    required int sensorIso,
    required double yLinear,
    required double targetEv,
  }) {
    final raw = fromCameraFrame(
      aperture: aperture,
      exposureSec: exposureSec,
      sensorIso: sensorIso,
      yLinear: yLinear,
      calibrationOffset: 0,
    );
    return targetEv - raw;
  }

  /// 降级公式：拿不到相机 metadata 时使用。
  ///
  /// 把 yLinear 视为反射率，按 K=12.5 反射光测光常数推 EV100：
  ///   EV100 = log2(yLinear · K · 100) + offset
  /// （等价于把"中灰对应 EV100=log2(0.18·12.5·100)≈7.81"作为参考点；用户可再校准）
  static double fromGrayMeanLinearFallback({
    required double yLinear,
    required double calibrationOffset,
  }) {
    final y = yLinear < _yLinearFloor ? _yLinearFloor : yLinear;
    final base = math.log(y * k * 100) / math.ln2;
    return base + calibrationOffset;
  }
}
