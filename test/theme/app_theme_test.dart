import 'package:film_go/theme/app_colors.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 测试中注入空 TextTheme，绕过 google_fonts 的运行时字体加载，
  // 避免在没有网络/字体 asset 的测试环境里抛异步错。
  // 我们只断言主题的颜色/亮度/Material 3 配置，这些不依赖字体。
  const fakeTextTheme = TextTheme();

  group('AppTheme', () {
    test('light 主题背景为白、前景为黑', () {
      final theme = AppTheme.light(textTheme: fakeTextTheme);
      expect(theme.scaffoldBackgroundColor, AppColors.white);
      expect(theme.colorScheme.onSurface, AppColors.black);
      expect(theme.brightness, Brightness.light);
    });

    test('dark 主题背景为黑、前景为白', () {
      final theme = AppTheme.dark(textTheme: fakeTextTheme);
      expect(theme.scaffoldBackgroundColor, AppColors.black);
      expect(theme.colorScheme.onSurface, AppColors.white);
      expect(theme.brightness, Brightness.dark);
    });

    test('两套主题都使用 Material 3', () {
      expect(AppTheme.light(textTheme: fakeTextTheme).useMaterial3, isTrue);
      expect(AppTheme.dark(textTheme: fakeTextTheme).useMaterial3, isTrue);
    });
  });
}
