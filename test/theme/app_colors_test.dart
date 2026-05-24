import 'package:film_go/theme/app_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors', () {
    test('paperWhite / charcoalBlack hex 与 spec 一致', () {
      expect(AppColors.paperWhite.value, 0xFFF5F1EA);
      expect(AppColors.charcoalBlack.value, 0xFF1B1816);
    });

    test('light surface 层级亮度: bg > surfaceHigh > surfaceLow', () {
      expect(
        AppColors.paperWhite.computeLuminance() >
            AppColors.surfaceHighLight.computeLuminance(),
        isTrue,
      );
      expect(
        AppColors.surfaceHighLight.computeLuminance() >
            AppColors.surfaceLowLight.computeLuminance(),
        isTrue,
      );
    });

    test('dark surface 层级亮度: surfaceHigh > surfaceLow > bg', () {
      expect(
        AppColors.surfaceHighDark.computeLuminance() >
            AppColors.surfaceLowDark.computeLuminance(),
        isTrue,
      );
      expect(
        AppColors.surfaceLowDark.computeLuminance() >
            AppColors.charcoalBlack.computeLuminance(),
        isTrue,
      );
    });

    test('divider / muted 在前/背景之间', () {
      final dl = AppColors.divider.computeLuminance();
      final ml = AppColors.muted.computeLuminance();
      expect(dl, lessThan(AppColors.paperWhite.computeLuminance()));
      expect(dl, greaterThan(AppColors.charcoalBlack.computeLuminance()));
      expect(ml, lessThan(dl), reason: 'muted 比 divider 更暗');
      expect(ml, greaterThan(AppColors.charcoalBlack.computeLuminance()));
    });

    test('darkroomRed 与 spotHighlight 是唯二非中性强调', () {
      expect(AppColors.darkroomRed.value, 0xFFB33A2A);
      expect(AppColors.spotHighlight.value, 0xFFE8C77A);
    });
  });
}
