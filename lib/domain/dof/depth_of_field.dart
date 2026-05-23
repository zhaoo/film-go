import 'package:film_go/domain/shared/aperture.dart';
import 'package:meta/meta.dart';

/// 景深计算结果。
///
/// 距离单位均为米；远景为 `null` 表示超出超焦距即等价无穷。
@immutable
class DofResult {
  const DofResult({
    required this.nearMeters,
    required this.farMeters,
    required this.hyperfocalMeters,
  });

  /// 近景距离（米）。
  final double nearMeters;

  /// 远景距离（米）；当对焦距离 ≥ 超焦距时为 null（视为无穷）。
  final double? farMeters;

  /// 超焦距（米）。
  final double hyperfocalMeters;
}

/// 景深 / 超焦距计算器。所有公式见 spec 附录 A。
class DepthOfField {
  const DepthOfField._();

  /// H = f²/(N·c) + f
  ///
  /// [focalLengthMm] 焦距（毫米），[aperture] 光圈，
  /// [circleOfConfusionMm] 弥散圆（毫米）。返回米。
  static double hyperfocalMeters({
    required double focalLengthMm,
    required Aperture aperture,
    required double circleOfConfusionMm,
  }) {
    if (circleOfConfusionMm <= 0) {
      throw ArgumentError.value(
        circleOfConfusionMm,
        'circleOfConfusionMm',
        '必须为正数',
      );
    }
    if (focalLengthMm <= 0) {
      throw ArgumentError.value(focalLengthMm, 'focalLengthMm', '必须为正数');
    }
    final hMm = (focalLengthMm * focalLengthMm) /
            (aperture.fNumber * circleOfConfusionMm) +
        focalLengthMm;
    return hMm / 1000.0;
  }

  /// 计算给定对焦距离下的近景 / 远景 / 超焦距。
  ///
  /// 标准 DOF 公式（H 含 +f 修正项）：
  ///   Dn = s·(H − f) / (H + s − 2f)
  ///   Df = s·(H − f) / (H − s)，当 s ≥ H 时 Df = ∞ → null。
  static DofResult compute({
    required double focalLengthMm,
    required Aperture aperture,
    required double circleOfConfusionMm,
    required double focusDistanceMeters,
  }) {
    if (focusDistanceMeters <= 0) {
      throw ArgumentError.value(
        focusDistanceMeters,
        'focusDistanceMeters',
        '必须为正数',
      );
    }
    final h = hyperfocalMeters(
      focalLengthMm: focalLengthMm,
      aperture: aperture,
      circleOfConfusionMm: circleOfConfusionMm,
    );
    final fMeters = focalLengthMm / 1000.0;
    final s = focusDistanceMeters;

    final near = (s * (h - fMeters)) / (h + s - 2 * fMeters);
    final double? far;
    if (s >= h) {
      far = null;
    } else {
      far = (s * (h - fMeters)) / (h - s);
    }
    return DofResult(
      nearMeters: near,
      farMeters: far,
      hyperfocalMeters: h,
    );
  }
}
