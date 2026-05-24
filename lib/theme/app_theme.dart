import 'package:film_go/theme/app_colors.dart';
import 'package:film_go/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Film Go 暖灰胶片主题构建器。
///
/// Light = 暖纸白 ([AppColors.paperWhite])，Dark = 暖炭黑 ([AppColors.charcoalBlack])；
/// 两套主题共享同一组暖灰 surface / divider / muted 层级。
/// 强调色仅保留 [AppColors.darkroomRed]（语义 = error / 危险）与 spot 暖黄。
class AppTheme {
  const AppTheme._();

  /// 构造亮色主题。
  ///
  /// [textTheme] 仅在测试中注入用，避免触发 google_fonts 的运行时字体抓取；
  /// 生产代码不要传，让默认 [AppTypography.buildTextTheme] 接管。
  static ThemeData light({TextTheme? textTheme}) =>
      _build(brightness: Brightness.light, textTheme: textTheme);

  /// 构造暗色主题。[textTheme] 同上，只给测试注入用。
  static ThemeData dark({TextTheme? textTheme}) =>
      _build(brightness: Brightness.dark, textTheme: textTheme);

  static ThemeData _build({
    required Brightness brightness,
    TextTheme? textTheme,
  }) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.charcoalBlack : AppColors.paperWhite;
    final fg = isDark ? AppColors.paperWhite : AppColors.charcoalBlack;
    final surfaceHigh =
        isDark ? AppColors.surfaceHighDark : AppColors.surfaceHighLight;
    final surfaceLow =
        isDark ? AppColors.surfaceLowDark : AppColors.surfaceLowLight;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: fg,
      onPrimary: bg,
      secondary: AppColors.muted,
      onSecondary: bg,
      surface: bg,
      onSurface: fg,
      surfaceContainerHighest: surfaceHigh,
      surfaceContainerHigh: surfaceLow,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.divider,
      outlineVariant: AppColors.divider,
      error: AppColors.darkroomRed,
      onError: AppColors.paperWhite,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: colorScheme,
      textTheme: textTheme ?? AppTypography.buildTextTheme(brightness),
    );
  }
}
