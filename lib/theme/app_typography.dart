import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Film Go 字体方案。
///
/// - 数字 / 英文：JetBrains Mono（仪表盘观感）
/// - 中文：iOS=PingFang SC，Android=系统默认（落 HarmonyOS Sans 或 Noto）
class AppTypography {
  const AppTypography._();

  static TextTheme buildTextTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;
    // google_fonts 是外部边界：测试 / 离线 / 字体抓取失败时回落到 base，不让 UI 崩。
    TextTheme themed;
    try {
      themed = GoogleFonts.jetBrainsMonoTextTheme(base);
    } catch (_) {
      themed = base;
    }
    return themed.apply(
      // 中文回落由 fontFamilyFallback 控制
      fontFamilyFallback: const [
        'PingFang SC',
        'HarmonyOS Sans',
        'Noto Sans CJK SC',
      ],
    );
  }
}
