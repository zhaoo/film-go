import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IsoValue', () {
    test('常见整档序列覆盖 ISO 25 到 6400', () {
      const stops = IsoValue.fullStops;
      expect(stops.first.value, 25);
      expect(stops.last.value, 6400);
      for (var i = 1; i < stops.length; i++) {
        final ratio = stops[i].value / stops[i - 1].value;
        expect(ratio, closeTo(2.0, 1e-9));
      }
    });

    test('display 直接输出整数', () {
      expect(IsoValue(400).display, 'ISO 400');
      expect(IsoValue(1600).display, 'ISO 1600');
    });

    test('两个相同 ISO 的对象相等', () {
      expect(IsoValue(400), IsoValue(400));
      expect(IsoValue(400).hashCode, IsoValue(400).hashCode);
    });

    test('非正 ISO 抛 ArgumentError', () {
      expect(() => IsoValue(0), throwsArgumentError);
      expect(() => IsoValue(-100), throwsArgumentError);
    });
  });
}
