import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvCalculator.fromExposure', () {
    test('f/1, 1s, ISO 100 = EV 0', () {
      final ev = EvCalculator.fromExposure(
        aperture: Aperture(1),
        shutter: ShutterSpeed.seconds(1),
        iso: 100,
      );
      expect(ev, closeTo(0, 1e-6));
    });

    test('f/16, 1/100s, ISO 100 ≈ EV 14.64（Sunny 16 教科书 ≈ EV 15）', () {
      final ev = EvCalculator.fromExposure(
        aperture: Aperture(16),
        shutter: ShutterSpeed.seconds(1 / 100),
        iso: 100,
      );
      // log2(16²/(1/100)) = log2(25600) ≈ 14.6439
      expect(ev, closeTo(14.64, 0.01));
    });

    test('ISO 提升 1 档等价于 EV +1', () {
      final at100 = EvCalculator.fromExposure(
        aperture: Aperture(8),
        shutter: ShutterSpeed.seconds(1 / 60),
        iso: 100,
      );
      final at200 = EvCalculator.fromExposure(
        aperture: Aperture(8),
        shutter: ShutterSpeed.seconds(1 / 60),
        iso: 200,
      );
      expect(at200 - at100, closeTo(1.0, 1e-9));
    });
  });

  group('EvCalculator.suggestPairs', () {
    test('给定 EV 与 ISO，输出整档光圈对应的快门组合，含 Sunny 16', () {
      final pairs = EvCalculator.suggestPairs(ev: 15, iso: 100);
      // f/16 → 1/100s 附近（Sunny 16）应该出现
      final hasSunny16 = pairs.any(
        (p) =>
            p.aperture == Aperture(16) &&
            (p.shutter.seconds - 1 / 125).abs() < 1 / 80,
      );
      expect(hasSunny16, isTrue);
      expect(pairs, isNotEmpty);
    });

    test('每个 pair 的快门都来自 ShutterSpeed.fullStops', () {
      final pairs = EvCalculator.suggestPairs(ev: 12, iso: 100);
      expect(pairs, isNotEmpty);
      for (final p in pairs) {
        final hit = ShutterSpeed.fullStops.any(
          (s) => (s.seconds - p.shutter.seconds).abs() < 1e-9,
        );
        expect(hit, isTrue, reason: '${p.shutter.display} 不在 fullStops');
      }
    });

    test('理论快门与最近整档误差 > 0.5 stop 时丢弃该光圈', () {
      // EV 0, ISO 100: f/1 → 1s（整档完美命中）
      // f/64 → 4096s，远超 30s，应丢弃
      final pairs = EvCalculator.suggestPairs(ev: 0, iso: 100);
      expect(pairs.any((p) => p.aperture.fNumber == 1.0), isTrue);
      expect(pairs.any((p) => p.aperture.fNumber == 64.0), isFalse);
    });

    test('结果按光圈递增排序', () {
      final pairs = EvCalculator.suggestPairs(ev: 13, iso: 100);
      for (var i = 1; i < pairs.length; i++) {
        expect(
          pairs[i].aperture.fNumber,
          greaterThan(pairs[i - 1].aperture.fNumber),
        );
      }
    });
  });
}
