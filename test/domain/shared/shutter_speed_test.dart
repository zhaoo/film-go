import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShutterSpeed', () {
    test('seconds 必须 > 0', () {
      expect(() => ShutterSpeed.seconds(0), throwsArgumentError);
      expect(() => ShutterSpeed.seconds(-0.5), throwsArgumentError);
    });

    test('display 在 ≥1s 时输出秒、<1s 时输出 1/x', () {
      expect(ShutterSpeed.seconds(1).display, '1s');
      expect(ShutterSpeed.seconds(2).display, '2s');
      expect(ShutterSpeed.seconds(30).display, '30s');
      expect(ShutterSpeed.seconds(0.5).display, '1/2');
      expect(ShutterSpeed.seconds(1 / 250).display, '1/250');
      expect(ShutterSpeed.seconds(1 / 1000).display, '1/1000');
    });

    test('display 对长曝光保留 1 位小数', () {
      expect(ShutterSpeed.seconds(1.5).display, '1.5s');
    });

    test('相等性按 seconds 比较', () {
      expect(ShutterSpeed.seconds(0.5), ShutterSpeed.seconds(0.5));
      expect(
        ShutterSpeed.seconds(0.5).hashCode,
        ShutterSpeed.seconds(0.5).hashCode,
      );
    });
  });

  group('ShutterSpeed.fullStops', () {
    test('包含 30s 起到 1/8000 共 19 档', () {
      expect(ShutterSpeed.fullStops.length, 19);
      expect(ShutterSpeed.fullStops.first.seconds, 30.0);
      expect(ShutterSpeed.fullStops.last.seconds, closeTo(1 / 8000, 1e-9));
    });

    test('档与档之间近似差 1 stop（log2 比值 ≈ 1）', () {
      for (var i = 1; i < ShutterSpeed.fullStops.length; i++) {
        final prev = ShutterSpeed.fullStops[i - 1].seconds;
        final cur = ShutterSpeed.fullStops[i].seconds;
        // 序列是慢→快，所以 prev > cur
        final stops = (prev / cur);
        // 允许 1/2..1/4..1/8 vs 1/15 这种历史习惯偏差
        expect(stops, greaterThanOrEqualTo(1.6));
        expect(stops, lessThanOrEqualTo(2.2));
      }
    });

    test('display 字符串符合摄影惯例', () {
      expect(ShutterSpeed.fullStops.first.display, '30s');
      expect(ShutterSpeed.fullStops.last.display, '1/8000');
      expect(
        ShutterSpeed.fullStops.firstWhere((s) => s.display == '1/125'),
        isNotNull,
      );
    });
  });
}
