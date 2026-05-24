import 'package:film_go/theme/app_colors.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fakeTextTheme = TextTheme();

  group('AppTheme - light', () {
    late ThemeData t;
    setUp(() => t = AppTheme.light(textTheme: fakeTextTheme));

    test('背景 paperWhite，前景 charcoalBlack', () {
      expect(t.scaffoldBackgroundColor, AppColors.paperWhite);
      expect(t.colorScheme.surface, AppColors.paperWhite);
      expect(t.colorScheme.onSurface, AppColors.charcoalBlack);
    });

    test('surface 层级使用 light 系列', () {
      expect(t.colorScheme.surfaceContainerHighest, AppColors.surfaceHighLight);
      expect(t.colorScheme.surfaceContainerHigh, AppColors.surfaceLowLight);
    });

    test('outline / outlineVariant 用 divider，onSurfaceVariant 用 muted', () {
      expect(t.colorScheme.outline, AppColors.divider);
      expect(t.colorScheme.outlineVariant, AppColors.divider);
      expect(t.colorScheme.onSurfaceVariant, AppColors.muted);
    });

    test('error = darkroomRed', () {
      expect(t.colorScheme.error, AppColors.darkroomRed);
    });
  });

  group('AppTheme - dark', () {
    late ThemeData t;
    setUp(() => t = AppTheme.dark(textTheme: fakeTextTheme));

    test('背景 charcoalBlack，前景 paperWhite', () {
      expect(t.scaffoldBackgroundColor, AppColors.charcoalBlack);
      expect(t.colorScheme.surface, AppColors.charcoalBlack);
      expect(t.colorScheme.onSurface, AppColors.paperWhite);
    });

    test('surface 层级使用 dark 系列', () {
      expect(t.colorScheme.surfaceContainerHighest, AppColors.surfaceHighDark);
      expect(t.colorScheme.surfaceContainerHigh, AppColors.surfaceLowDark);
    });
  });

  test('两套主题都使用 Material 3', () {
    expect(AppTheme.light(textTheme: fakeTextTheme).useMaterial3, isTrue);
    expect(AppTheme.dark(textTheme: fakeTextTheme).useMaterial3, isTrue);
  });
}
