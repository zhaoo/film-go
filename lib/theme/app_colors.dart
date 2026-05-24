import 'package:flutter/material.dart';

/// Film Go 暖灰胶片色板。
///
/// 摒弃严格黑白二元，改为带轻微暖调的纸感与炭黑：
/// - 中性背景 / 前景以 paperWhite / charcoalBlack 为锚
/// - 两级 surface 用于卡片、滚轮高亮带、底栏
/// - 强调色保留暗房红（darkroomRed）与 spot 暖黄（spotHighlight）
class AppColors {
  const AppColors._();

  // 主底色 / 前景
  static const Color paperWhite = Color(0xFFF5F1EA);
  static const Color charcoalBlack = Color(0xFF1B1816);

  // light 模式 surface 层级（自底向高）
  static const Color surfaceLowLight = Color(0xFFDDD6C8);
  static const Color surfaceHighLight = Color(0xFFECE6DC);

  // dark 模式 surface 层级（自底向高）
  static const Color surfaceLowDark = Color(0xFF221E1B);
  static const Color surfaceHighDark = Color(0xFF2A2522);

  // 中性辅助
  static const Color divider = Color(0xFFBDB4A4);
  static const Color muted = Color(0xFF6F665C);

  // 强调色（语义保留）

  /// 唯一语义强调色，仅限：① 错误/告警态（ColorScheme.error）；
  /// ② 暗房录制/危险操作指示。禁止当作装饰色使用。
  static const Color darkroomRed = Color(0xFFB33A2A);

  /// Pro 视图 spot 框 / 滚轮中央高亮带 / 当前选中刻度专用，
  /// 胶片调暖黄；不用于通用强调或装饰。
  static const Color spotHighlight = Color(0xFFE8C77A);
}
