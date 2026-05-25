import 'package:film_go/domain/dof/film_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilmFormat', () {
    test('4 档枚举值齐全且顺序为 135 → 6×6 → 6×7 → 4×5', () {
      expect(FilmFormat.values, [
        FilmFormat.f135,
        FilmFormat.f6x6,
        FilmFormat.f6x7,
        FilmFormat.f4x5,
      ]);
    });

    test('每档 label 与摄影惯例一致', () {
      expect(FilmFormat.f135.label, '135');
      expect(FilmFormat.f6x6.label, '6×6');
      expect(FilmFormat.f6x7.label, '6×7');
      expect(FilmFormat.f4x5.label, '4×5');
    });

    test('每档 cocMm 与 spec 一致', () {
      expect(FilmFormat.f135.cocMm, 0.030);
      expect(FilmFormat.f6x6.cocMm, 0.060);
      expect(FilmFormat.f6x7.cocMm, 0.066);
      expect(FilmFormat.f4x5.cocMm, 0.150);
    });
  });
}
