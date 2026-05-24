import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvStop', () {
    test('zero stop is 0', () {
      expect(EvStop.zero.stops, 0.0);
      expect(EvStop.zero.thirds, 0);
    });

    test('thirds-based factory builds value', () {
      expect(EvStop.thirds(1).thirds, 1);
      expect(EvStop.thirds(-3).thirds, -3);
      expect(EvStop.thirds(9).thirds, 9);
      expect(EvStop.thirds(-9).thirds, -9);
    });

    test('range is clamped to [-9..9] thirds (= ±3 stop)', () {
      expect(() => EvStop.thirds(10), throwsArgumentError);
      expect(() => EvStop.thirds(-10), throwsArgumentError);
    });

    test('stops returns thirds * 1/3', () {
      expect(EvStop.thirds(3).stops, closeTo(1.0, 1e-9));
      expect(EvStop.thirds(-3).stops, closeTo(-1.0, 1e-9));
      expect(EvStop.thirds(2).stops, closeTo(2 / 3, 1e-9));
      expect(EvStop.thirds(-1).stops, closeTo(-1 / 3, 1e-9));
    });

    test('addition adds thirds', () {
      expect((EvStop.thirds(1) + EvStop.thirds(1)).thirds, 2);
      expect((EvStop.thirds(2) + EvStop.thirds(1)).thirds, 3);
      expect((EvStop.thirds(-3) + EvStop.thirds(1)).thirds, -2);
      expect((EvStop.thirds(9) + EvStop.thirds(-9)).thirds, 0);
    });

    test('addition outside range clamps to limits', () {
      expect((EvStop.thirds(9) + EvStop.thirds(1)).thirds, 9);
      expect((EvStop.thirds(-9) + EvStop.thirds(-1)).thirds, -9);
    });

    test('display formats as third-of-stop fractions', () {
      expect(EvStop.zero.display, '0');
      expect(EvStop.thirds(1).display, '+1/3');
      expect(EvStop.thirds(2).display, '+2/3');
      expect(EvStop.thirds(3).display, '+1');
      expect(EvStop.thirds(4).display, '+1 1/3');
      expect(EvStop.thirds(5).display, '+1 2/3');
      expect(EvStop.thirds(6).display, '+2');
      expect(EvStop.thirds(9).display, '+3');
      expect(EvStop.thirds(-1).display, '-1/3');
      expect(EvStop.thirds(-2).display, '-2/3');
      expect(EvStop.thirds(-3).display, '-1');
      expect(EvStop.thirds(-4).display, '-1 1/3');
      expect(EvStop.thirds(-9).display, '-3');
    });

    test('range constants', () {
      expect(EvStop.minThirds, -9);
      expect(EvStop.maxThirds, 9);
    });

    test('values list covers all 19 thirds in order', () {
      final vs = EvStop.values;
      expect(vs.length, 19);
      expect(vs.first.thirds, -9);
      expect(vs.last.thirds, 9);
      for (var i = 1; i < vs.length; i++) {
        expect(vs[i].thirds - vs[i - 1].thirds, 1);
      }
    });

    test('equality and hashCode', () {
      expect(EvStop.thirds(2), EvStop.thirds(2));
      expect(EvStop.thirds(2).hashCode, EvStop.thirds(2).hashCode);
      expect(EvStop.thirds(2) == EvStop.thirds(3), isFalse);
    });
  });
}
