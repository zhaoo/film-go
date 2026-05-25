import 'package:film_go/domain/dof/depth_of_field.dart';
import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:meta/meta.dart';

/// 景深页输入与派生计算结果。所有派生 getter 都是 pure。
@immutable
class DofState {
  const DofState({
    required this.focusDistIndex,
    required this.focalLengthMm,
    required this.apertureIndex,
    required this.format,
  });

  /// 16 档镜头标尺距离（米），末位为 `double.infinity`。
  static const List<double> focusSteps = <double>[
    0.3, 0.5, 0.7, 1, 1.5, 2, 3, 5, 7, 10, 15, 20, 30, 50, 100,
    double.infinity,
  ];

  /// 默认：5m / 50mm / f/8 / 135。
  static const DofState initial = DofState(
    focusDistIndex: 7,
    focalLengthMm: 50,
    apertureIndex: 6,
    format: FilmFormat.f135,
  );

  final int focusDistIndex;
  final int focalLengthMm;
  final int apertureIndex;
  final FilmFormat format;

  double get focusMeters => focusSteps[focusDistIndex];
  Aperture get aperture => Aperture.fullStops[apertureIndex];
  double get cocMm => format.cocMm;

  DofResult get result {
    final h = DepthOfField.hyperfocalMeters(
      focalLengthMm: focalLengthMm.toDouble(),
      aperture: aperture,
      circleOfConfusionMm: cocMm,
    );
    if (!focusMeters.isFinite) {
      return DofResult(
        nearMeters: h,
        farMeters: null,
        hyperfocalMeters: h,
      );
    }
    return DepthOfField.compute(
      focalLengthMm: focalLengthMm.toDouble(),
      aperture: aperture,
      circleOfConfusionMm: cocMm,
      focusDistanceMeters: focusMeters,
    );
  }

  DofState copyWith({
    int? focusDistIndex,
    int? focalLengthMm,
    int? apertureIndex,
    FilmFormat? format,
  }) {
    return DofState(
      focusDistIndex: focusDistIndex ?? this.focusDistIndex,
      focalLengthMm: focalLengthMm ?? this.focalLengthMm,
      apertureIndex: apertureIndex ?? this.apertureIndex,
      format: format ?? this.format,
    );
  }
}
