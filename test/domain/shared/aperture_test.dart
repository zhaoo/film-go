import 'package:film_go/domain/shared/aperture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aperture', () {
    test('整档序列覆盖 f/1 到 f/64', () {
      const stops = Aperture.fullStops;
      expect(stops.first.fNumber, closeTo(1.0, 1e-9));
      expect(stops.last.fNumber, closeTo(64.0, 1e-9));
      // 整档比相邻 f 值约 √2
      for (var i = 1; i < stops.length; i++) {
        final ratio = stops[i].fNumber / stops[i - 1].fNumber;
        expect(ratio, closeTo(1.41421356, 0.01));
      }
    });

    test('display 字符串符合摄影惯例 f/2.8', () {
      expect(Aperture(2.8).display, 'f/2.8');
      expect(Aperture(8).display, 'f/8');
      expect(Aperture(1.4).display, 'f/1.4');
    });

    test('两个相同 f 值的 Aperture 相等', () {
      expect(Aperture(2.8), Aperture(2.8));
      expect(Aperture(2.8).hashCode, Aperture(2.8).hashCode);
    });

    test('非正 f 值抛 ArgumentError', () {
      expect(() => Aperture(0), throwsArgumentError);
      expect(() => Aperture(-1), throwsArgumentError);
    });

    test('fullStops 显示符合摄影惯例 (f/5.6, f/11, f/22, f/45)', () {
      const expected = [
        'f/1',
        'f/1.4',
        'f/2',
        'f/2.8',
        'f/4',
        'f/5.6',
        'f/8',
        'f/11',
        'f/16',
        'f/22',
        'f/32',
        'f/45',
        'f/64',
      ];
      final actual = Aperture.fullStops.map((a) => a.display).toList();
      expect(actual, expected);
    });
  });
}
