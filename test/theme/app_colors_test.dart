import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('黑白主色 hex 与 spec 一致', () {
      expect(AppColors.black.value, 0xFF0A0A0A);
      expect(AppColors.white.value, 0xFFFAFAFA);
    });

    test('灰阶 5 级单调递增', () {
      final grays = <Color>[
        AppColors.gray900,
        AppColors.gray700,
        AppColors.gray500,
        AppColors.gray300,
        AppColors.gray100,
      ];
      for (var i = 1; i < grays.length; i++) {
        expect(
          grays[i].computeLuminance() > grays[i - 1].computeLuminance(),
          isTrue,
          reason: 'gray index $i 应比上一个更亮',
        );
      }
    });

    test('暗房红是唯一允许的彩色', () {
      expect(AppColors.darkroomRed.value, 0xFFC8302A);
    });
  });
}
