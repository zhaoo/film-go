import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IsoValue.thirdStops', () {
    test('25 entries, 25 -> 6400', () {
      const ts = IsoValue.thirdStops;
      expect(ts.length, 25);
      expect(ts.first.value, 25);
      expect(ts.last.value, 6400);
    });

    test('adjacent ratio ~ 2^(1/3)', () {
      const ts = IsoValue.thirdStops;
      const cubeRoot2 = 1.2599210498948732;
      for (var i = 1; i < ts.length; i++) {
        final ratio = ts[i].value / ts[i - 1].value;
        expect(
          ratio,
          closeTo(cubeRoot2, 0.06),
          reason: '$i: ${ts[i - 1].value} -> ${ts[i].value} ratio=$ratio',
        );
      }
    });

    test('contains canonical full stops', () {
      const expected = [25, 50, 100, 200, 400, 800, 1600, 3200, 6400];
      for (final v in expected) {
        expect(
          IsoValue.thirdStops.any((iso) => iso.value == v),
          isTrue,
          reason: 'thirdStops should include ISO $v',
        );
      }
    });

    test('canonical 1/3 stops are present', () {
      const expectedThirds = [125, 160, 250, 320, 500, 640, 1000, 1250];
      for (final v in expectedThirds) {
        expect(
          IsoValue.thirdStops.any((iso) => iso.value == v),
          isTrue,
          reason: 'thirdStops should include ISO $v (1/3 stop)',
        );
      }
    });
  });
}
