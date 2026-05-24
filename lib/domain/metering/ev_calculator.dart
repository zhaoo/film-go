import 'dart:math' as math;

import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:meta/meta.dart';

/// 一组曝光参数：光圈 + 快门。供 [EvCalculator.suggestPairs] 输出使用。
@immutable
class ExposurePair {
  const ExposurePair({required this.aperture, required this.shutter});
  final Aperture aperture;
  final ShutterSpeed shutter;
}

/// EV 双向换算工具。
///
/// 反射光测光不涉及 K 常数，本工具只做相机曝光参数 ↔ EV 的可逆换算。
class EvCalculator {
  const EvCalculator._();

  /// EV (at given ISO) = log2(N² / t) + log2(ISO / 100)
  static double fromExposure({
    required Aperture aperture,
    required ShutterSpeed shutter,
    required int iso,
  }) {
    final n2OverT = (aperture.fNumber * aperture.fNumber) / shutter.seconds;
    final isoTerm = math.log(iso / 100) / math.ln2;
    final base = math.log(n2OverT) / math.ln2;
    return base + isoTerm;
  }

  /// 给定 EV 与 ISO，遍历整档光圈给出对应快门组合。
  ///
  /// 理论快门 = N² / 2^(EV - log2(ISO/100))；与 [ShutterSpeed.fullStops]
  /// 中最近一档吸附（按 |log2| 距离）。若距离超过 0.5 stop（如理论值
  /// 落在 30s..1/8000 之外）则丢弃该光圈。
  static List<ExposurePair> suggestPairs({
    required double ev,
    required int iso,
  }) {
    const tolerance = 0.5; // stop
    final isoTerm = math.log(iso / 100) / math.ln2;
    final ev100 = ev - isoTerm;
    final pairs = <ExposurePair>[];
    for (final ap in Aperture.fullStops) {
      final theory = (ap.fNumber * ap.fNumber) / math.pow(2, ev100);
      if (theory <= 0 || theory.isInfinite || theory.isNaN) continue;
      final snapped = _snapShutter(theory);
      if (snapped == null) continue;
      final dist = (math.log(theory / snapped.seconds) / math.ln2).abs();
      if (dist > tolerance) continue;
      pairs.add(ExposurePair(aperture: ap, shutter: snapped));
    }
    return pairs;
  }

  static ShutterSpeed? _snapShutter(double targetSec) {
    ShutterSpeed? best;
    var bestDist = double.infinity;
    for (final s in ShutterSpeed.fullStops) {
      final d = (math.log(targetSec / s.seconds) / math.ln2).abs();
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }
}
