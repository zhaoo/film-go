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
}
