import 'package:film_go/domain/shared/nd_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NdFilter', () {
    test('none has 0 stops', () {
      expect(NdFilter.none.stops, 0.0);
    });

    test('ND2..ND1024 matches log2', () {
      expect(NdFilter.nd2.stops, closeTo(1, 1e-9));
      expect(NdFilter.nd4.stops, closeTo(2, 1e-9));
      expect(NdFilter.nd8.stops, closeTo(3, 1e-9));
      expect(NdFilter.nd16.stops, closeTo(4, 1e-9));
      expect(NdFilter.nd32.stops, closeTo(5, 1e-9));
      expect(NdFilter.nd64.stops, closeTo(6, 1e-9));
      expect(NdFilter.nd128.stops, closeTo(7, 1e-9));
      expect(NdFilter.nd256.stops, closeTo(8, 1e-9));
      expect(NdFilter.nd512.stops, closeTo(9, 1e-9));
      expect(NdFilter.nd1024.stops, closeTo(10, 1e-9));
    });

    test('display labels', () {
      expect(NdFilter.none.display, '0');
      expect(NdFilter.nd2.display, 'ND2');
      expect(NdFilter.nd1024.display, 'ND1024');
    });

    test('values is ordered none -> nd1024', () {
      const vs = NdFilter.values;
      expect(vs.length, 11);
      expect(vs.first, NdFilter.none);
      expect(vs.last, NdFilter.nd1024);
      for (var i = 1; i < vs.length; i++) {
        expect(vs[i].stops, greaterThan(vs[i - 1].stops));
      }
    });
  });
}
