import 'package:film_go/domain/dof/depth_of_field.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DepthOfField', () {
    test('35mm + 50mm + f/8，超焦距约 10.5m', () {
      final h = DepthOfField.hyperfocalMeters(
        focalLengthMm: 50,
        aperture: Aperture(8),
        circleOfConfusionMm: 0.030,
      );
      expect(h, closeTo(10.47, 0.1));
    });

    test('对焦距离等于超焦距时，Df 为无穷', () {
      final result = DepthOfField.compute(
        focalLengthMm: 50,
        aperture: Aperture(8),
        circleOfConfusionMm: 0.030,
        focusDistanceMeters: 10.47,
      );
      expect(result.farMeters, isNull, reason: '∞ 用 null 表示');
    });

    test('近景 < 对焦距离 < 远景', () {
      final result = DepthOfField.compute(
        focalLengthMm: 50,
        aperture: Aperture(2.8),
        circleOfConfusionMm: 0.030,
        focusDistanceMeters: 3.0,
      );
      expect(result.nearMeters, lessThan(3.0));
      expect(result.farMeters, isNotNull);
      expect(result.farMeters, greaterThan(3.0));
    });

    test('光圈缩小景深变深（远景延伸）', () {
      double dfAt(double n) {
        final r = DepthOfField.compute(
          focalLengthMm: 50,
          aperture: Aperture(n),
          circleOfConfusionMm: 0.030,
          focusDistanceMeters: 3.0,
        );
        return r.farMeters!;
      }

      expect(dfAt(2.8), lessThan(dfAt(8)));
      expect(dfAt(8), lessThan(dfAt(16)));
    });

    test('CoC ≤ 0 抛 ArgumentError', () {
      expect(
        () => DepthOfField.hyperfocalMeters(
          focalLengthMm: 50,
          aperture: Aperture(8),
          circleOfConfusionMm: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
