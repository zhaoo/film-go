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
  /// 推荐快门 = N² / 2^(EV - log2(ISO/100))
  /// 实用范围：1/8000s ~ 30s
  static List<ExposurePair> suggestPairs({
    required double ev,
    required int iso,
  }) {
    final isoTerm = math.log(iso / 100) / math.ln2;
    final ev100 = ev - isoTerm;
    final pairs = <ExposurePair>[];
    for (final ap in Aperture.fullStops) {
      final shutterSec = (ap.fNumber * ap.fNumber) / math.pow(2, ev100);
      if (shutterSec <= 0 || shutterSec.isInfinite || shutterSec.isNaN) {
        continue;
      }
      if (shutterSec < 1 / 8000 || shutterSec > 30) continue;
      pairs.add(
        ExposurePair(
          aperture: ap,
          shutter: ShutterSpeed.seconds(shutterSec),
        ),
      );
    }
    return pairs;
  }
}
