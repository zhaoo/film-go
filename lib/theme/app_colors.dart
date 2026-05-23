import 'package:flutter/material.dart';

/// Film Go 黑白色板。
///
/// 全局唯一允许的非黑白色是 [darkroomRed]，仅用于：
///   ① 测光“超出范围”警示
///   ② 冲洗计时器氛围
/// 任何其他场景禁止使用红色或彩色。
class AppColors {
  const AppColors._();

  // 主色
  static const Color black = Color(0xFF0A0A0A);
  static const Color white = Color(0xFFFAFAFA);

  // 5 级灰阶（深→浅）
  static const Color gray900 = Color(0xFF1F1F1F);
  static const Color gray700 = Color(0xFF3A3A3A);
  static const Color gray500 = Color(0xFF6B6B6B);
  static const Color gray300 = Color(0xFFB5B5B5);
  static const Color gray100 = Color(0xFFE5E5E5);

  // 唯一强调色
  static const Color darkroomRed = Color(0xFFC8302A);
}
