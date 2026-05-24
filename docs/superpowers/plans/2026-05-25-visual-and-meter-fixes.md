# 视觉系统暖化 + 测光交互修复 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把全 app 配色从严格黑白升级为暖灰胶片调；快速测光改成整档快门 + 双滚轮；修复专业测光拍照失效。

**Architecture:** 配色层在 `AppColors` 新 token + `AppTheme` 注入 surface/outline 层级；快门刻度在 `ShutterSpeed.fullStops` 加常量序列后让 `EvCalculator.suggestPairs` 把理论值吸附到整档；`DualScale` 改为双 `ListWheelScrollView`，通过 `QuickModeState.userPairOffset` 记录用户手动偏移；专业测光拍照在 capture 闭包内用 `stop()/start()` 包住 `takePicture()` 并把 `saveToGallery` 真接 `image_gallery_saver`。

**Tech Stack:** Flutter 3.5 / Dart, flutter_riverpod, `camera ^0.11`, `image_gallery_saver ^2.0`, `image ^4.1`, flutter_test + mocktail。

参考 spec：`docs/superpowers/specs/2026-05-25-visual-and-meter-fixes-design.md`

---

## Task 1: 重写 AppColors 暖灰色板

**Files:**
- Modify: `lib/theme/app_colors.dart` — 全文替换
- Test: `test/theme/app_colors_test.dart` — 全文替换

- [ ] **Step 1: 重写色板测试（TDD）**

替换 `test/theme/app_colors_test.dart` 全文为：

```dart
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';
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
    });

    test('darkroomRed 与 spotHighlight 是唯二非中性强调', () {
      expect(AppColors.darkroomRed.value, 0xFFB33A2A);
      expect(AppColors.spotHighlight.value, 0xFFE8C77A);
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/theme/app_colors_test.dart`
Expected: 编译失败，未定义 `paperWhite` / `charcoalBlack` / `surfaceHighLight` 等。

- [ ] **Step 3: 重写 AppColors**

替换 `lib/theme/app_colors.dart` 全文为：

```dart
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
  static const Color darkroomRed = Color(0xFFB33A2A);

  /// Pro 视图 spot 框 / 高亮选中带，胶片调暖黄。
  static const Color spotHighlight = Color(0xFFE8C77A);
}
```

- [ ] **Step 4: 验证测试通过**

Run: `flutter test test/theme/app_colors_test.dart`
Expected: 全部 PASS（5 个 case）。

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_colors.dart test/theme/app_colors_test.dart
git commit -m "feat(theme): 暖灰胶片色板替换严格黑白"
```

---

## Task 2: AppTheme 注入 surface/outline/muted 层级

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Test: `test/theme/app_theme_test.dart` — 全文替换

- [ ] **Step 1: 重写 theme 测试（TDD）**

替换 `test/theme/app_theme_test.dart` 全文为：

```dart
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
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/theme/app_theme_test.dart`
Expected: FAIL，新 token 未在 ColorScheme 中注入。

- [ ] **Step 3: 重写 AppTheme._build**

替换 `lib/theme/app_theme.dart` 的 `_build` 函数体（保留类与公开签名）：

```dart
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
```

- [ ] **Step 4: 验证 theme 测试 + 全套测试**

Run: `flutter test test/theme/`
Expected: 全部 PASS。

Run: `flutter test`
Expected: 全部 PASS（其他测试不应受影响——Pro widget 测试只是把 `Colors.black` 作为测试 Scaffold 背景，不耦合）。

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme.dart test/theme/app_theme_test.dart
git commit -m "feat(theme): ColorScheme 注入 surface/outline/muted 层级"
```

---

## Task 3: Pro 视图配色去硬编码

**Files:**
- Modify: `lib/pages/meter/meter_page.dart:110`
- Modify: `lib/pages/meter/pro/pro_meter_view.dart:149,151`
- Modify: `lib/pages/meter/pro/widgets/pro_top_status_bar.dart`
- Modify: `lib/pages/meter/pro/widgets/shutter_button.dart`
- Modify: `lib/pages/meter/pro/widgets/pro_readout.dart`
- Modify: `lib/pages/meter/pro/widgets/meter_mode_cycle_button.dart`
- Modify: `lib/pages/meter/pro/widgets/scale_strip.dart`
- Modify: `lib/pages/meter/pro/widgets/spot_overlay.dart`

> 全部用 `AppColors`/`ColorScheme` 替换硬编码。Pro 全屏取景背景仍是黑底，但走 token。

- [ ] **Step 1: 替换 meter_page 背景**

`lib/pages/meter/meter_page.dart` 顶部 import 区追加：

```dart
import 'package:film_go/theme/app_colors.dart';
```

把第 110 行：

```dart
backgroundColor: isPro ? Colors.black : null,
```

改为：

```dart
backgroundColor: isPro ? AppColors.charcoalBlack : null,
```

- [ ] **Step 2: 替换 pro_meter_view 占位**

`lib/pages/meter/pro/pro_meter_view.dart` 顶部 import 追加：

```dart
import 'package:film_go/theme/app_colors.dart';
```

替换 `_PreviewPlaceholder.build`：

```dart
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.charcoalBlack,
      child: Center(
        child: Icon(
          Icons.camera_alt_outlined,
          size: 48,
          color: AppColors.paperWhite.withOpacity(0.24),
        ),
      ),
    );
  }
```

- [ ] **Step 3: 替换 pro_top_status_bar**

Read `lib/pages/meter/pro/widgets/pro_top_status_bar.dart` 确认当前结构，把 `Colors.white` 改为 `AppColors.paperWhite`（顶部状态栏覆在黑底取景上，前景需亮色，不能用 `cs.onSurface`，因为该 widget 没有自己的 surface 来源）。

补 import：

```dart
import 'package:film_go/theme/app_colors.dart';
```

- [ ] **Step 4: 替换 shutter_button**

`lib/pages/meter/pro/widgets/shutter_button.dart`：把所有 `Colors.white`（容器填充、描边、内圈）改为 `AppColors.paperWhite`；`Colors.black54`（进度圈）改为 `AppColors.charcoalBlack.withOpacity(0.54)`。

补 import。

- [ ] **Step 5: 替换 pro_readout / meter_mode_cycle_button / scale_strip / spot_overlay**

每个文件统一替换：
- `Colors.white` → `AppColors.paperWhite`
- `Colors.white60/70/24` → `AppColors.paperWhite.withOpacity(0.60/0.70/0.24)`
- `Colors.black54` → `AppColors.charcoalBlack.withOpacity(0.54)`
- `Colors.amber`（`scale_strip.dart:82` 与 `spot_overlay.dart:39`）→ `AppColors.spotHighlight`

每个文件顶部加 `import 'package:film_go/theme/app_colors.dart';`。

- [ ] **Step 6: 跑全套测试**

Run: `flutter test`
Expected: 全部 PASS。Pro widget 测试不断言具体颜色值，只验结构和回调，不会因 token 替换破。

- [ ] **Step 7: Commit**

```bash
git add lib/pages/meter/
git commit -m "feat(theme): Pro 视图配色迁移到 AppColors token"
```

---

## Task 4: ShutterSpeed.fullStops 整档常量

**Files:**
- Modify: `lib/domain/shared/shutter_speed.dart`
- Test: `test/domain/shared/shutter_speed_test.dart`

- [ ] **Step 1: 写失败测试（TDD）**

在 `test/domain/shared/shutter_speed_test.dart` 末尾 `group('ShutterSpeed', ...)` 之外追加：

```dart
import 'package:film_go/domain/shared/shutter_speed.dart';
// ↑ 已存在，无需重复

void _additional() {}  // placeholder marker, ignore
```

实际：在文件末尾追加一个新 group：

```dart
  group('ShutterSpeed.fullStops', () {
    test('包含 30s 起到 1/8000 共 19 档', () {
      expect(ShutterSpeed.fullStops.length, 19);
      expect(ShutterSpeed.fullStops.first.seconds, 30.0);
      expect(ShutterSpeed.fullStops.last.seconds, closeTo(1 / 8000, 1e-9));
    });

    test('档与档之间近似差 1 stop（log2 比值 ≈ 1）', () {
      for (var i = 1; i < ShutterSpeed.fullStops.length; i++) {
        final prev = ShutterSpeed.fullStops[i - 1].seconds;
        final cur = ShutterSpeed.fullStops[i].seconds;
        // 序列是慢→快，所以 prev > cur
        final stops = (prev / cur);
        // 允许 1/2..1/4..1/8 vs 1/15 这种历史习惯偏差
        expect(stops, greaterThanOrEqualTo(1.6));
        expect(stops, lessThanOrEqualTo(2.2));
      }
    });

    test('display 字符串符合摄影惯例', () {
      expect(ShutterSpeed.fullStops.first.display, '30s');
      expect(ShutterSpeed.fullStops.last.display, '1/8000');
      expect(
        ShutterSpeed.fullStops.firstWhere((s) => s.display == '1/125'),
        isNotNull,
      );
    });
  });
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/domain/shared/shutter_speed_test.dart`
Expected: FAIL，`ShutterSpeed.fullStops` 未定义。

- [ ] **Step 3: 加 `_unchecked` const 构造 + `fullStops` 常量**

替换 `lib/domain/shared/shutter_speed.dart` 全文为：

```dart
import 'package:meta/meta.dart';

/// 快门速度值对象。
@immutable
class ShutterSpeed {
  /// 以秒为单位构造。`seconds` 必须为正。
  ShutterSpeed.seconds(this.seconds) {
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds', '必须为正数');
    }
  }

  /// 仅供 [fullStops] 这类编译期合法常量使用，跳过运行时校验。
  const ShutterSpeed._unchecked(this.seconds);

  final double seconds;

  /// ≥1 秒：整数 `30s`，非整数 `1.5s`；<1 秒：`1/250`（取最近整数分母）。
  String get display {
    if (seconds >= 1) {
      if (seconds == seconds.roundToDouble()) {
        return '${seconds.toStringAsFixed(0)}s';
      }
      return '${seconds.toStringAsFixed(1)}s';
    }
    final denom = (1 / seconds).round();
    return '1/$denom';
  }

  /// 摄影惯例的整档快门序列，慢→快共 19 档。
  ///
  /// 1/15s 后保持 1, 2, 4, 8... 的传统分母（1/30 → 1/60 等），符合相机
  /// 转盘刻度，便于 EvCalculator 把理论值吸附到这里。
  static const List<ShutterSpeed> fullStops = <ShutterSpeed>[
    ShutterSpeed._unchecked(30),
    ShutterSpeed._unchecked(15),
    ShutterSpeed._unchecked(8),
    ShutterSpeed._unchecked(4),
    ShutterSpeed._unchecked(2),
    ShutterSpeed._unchecked(1),
    ShutterSpeed._unchecked(1 / 2),
    ShutterSpeed._unchecked(1 / 4),
    ShutterSpeed._unchecked(1 / 8),
    ShutterSpeed._unchecked(1 / 15),
    ShutterSpeed._unchecked(1 / 30),
    ShutterSpeed._unchecked(1 / 60),
    ShutterSpeed._unchecked(1 / 125),
    ShutterSpeed._unchecked(1 / 250),
    ShutterSpeed._unchecked(1 / 500),
    ShutterSpeed._unchecked(1 / 1000),
    ShutterSpeed._unchecked(1 / 2000),
    ShutterSpeed._unchecked(1 / 4000),
    ShutterSpeed._unchecked(1 / 8000),
  ];

  @override
  bool operator ==(Object other) =>
      other is ShutterSpeed && other.seconds == seconds;

  @override
  int get hashCode => seconds.hashCode;
}
```

- [ ] **Step 4: 验证测试通过**

Run: `flutter test test/domain/shared/shutter_speed_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/domain/shared/shutter_speed.dart test/domain/shared/shutter_speed_test.dart
git commit -m "feat(shutter): fullStops 整档常量 (30s..1/8000)"
```

---

## Task 5: EvCalculator.suggestPairs 吸附整档快门

**Files:**
- Modify: `lib/domain/metering/ev_calculator.dart`
- Test: `test/domain/metering/ev_calculator_test.dart`

- [ ] **Step 1: 追加 snap 测试（TDD）**

在 `test/domain/metering/ev_calculator_test.dart` 的 `group('EvCalculator.suggestPairs', ...)` 内追加：

```dart
    test('每个 pair 的快门都来自 ShutterSpeed.fullStops', () {
      final pairs = EvCalculator.suggestPairs(ev: 12, iso: 100);
      expect(pairs, isNotEmpty);
      for (final p in pairs) {
        final hit = ShutterSpeed.fullStops.any(
          (s) => (s.seconds - p.shutter.seconds).abs() < 1e-9,
        );
        expect(hit, isTrue, reason: '${p.shutter.display} 不在 fullStops');
      }
    });

    test('理论快门与最近整档误差 > 0.5 stop 时丢弃该光圈', () {
      // EV 0, ISO 100: f/1 → 1s（整档完美命中）
      // f/64 → 4096s，远超 30s，应丢弃
      final pairs = EvCalculator.suggestPairs(ev: 0, iso: 100);
      expect(pairs.any((p) => p.aperture.fNumber == 1.0), isTrue);
      expect(pairs.any((p) => p.aperture.fNumber == 64.0), isFalse);
    });

    test('结果按光圈递增排序', () {
      final pairs = EvCalculator.suggestPairs(ev: 13, iso: 100);
      for (var i = 1; i < pairs.length; i++) {
        expect(pairs[i].aperture.fNumber, greaterThan(pairs[i - 1].aperture.fNumber));
      }
    });
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/domain/metering/ev_calculator_test.dart`
Expected: 第 1 个新 case FAIL（旧实现给的是 `t = N²/2^EV` 自由值，不在 fullStops 里）。

- [ ] **Step 3: 重写 suggestPairs**

替换 `lib/domain/metering/ev_calculator.dart` 的 `suggestPairs`：

```dart
  /// 给定 EV 与 ISO，遍历整档光圈给出对应快门组合。
  ///
  /// 理论快门 = N² / 2^(EV - log2(ISO/100))；与 [ShutterSpeed.fullStops]
  /// 中最近一档吸附（按 |log2| 距离）。若距离超过 0.5 stop（如理论值
  /// 落在 30s..1/8000 之外）则丢弃该光圈。
  static List<ExposurePair> suggestPairs({
    required double ev,
    required int iso,
  }) {
    const tolerance = 0.5; // stop
    final isoTerm = math.log(iso / 100) / math.ln2;
    final ev100 = ev - isoTerm;
    final pairs = <ExposurePair>[];
    for (final ap in Aperture.fullStops) {
      final theory = (ap.fNumber * ap.fNumber) / math.pow(2, ev100);
      if (theory <= 0 || theory.isInfinite || theory.isNaN) continue;
      final snapped = _snapShutter(theory);
      if (snapped == null) continue;
      final dist = (math.log(theory / snapped.seconds) / math.ln2).abs();
      if (dist > tolerance) continue;
      pairs.add(ExposurePair(aperture: ap, shutter: snapped));
    }
    return pairs;
  }

  static ShutterSpeed? _snapShutter(double targetSec) {
    ShutterSpeed? best;
    var bestDist = double.infinity;
    for (final s in ShutterSpeed.fullStops) {
      final d = (math.log(targetSec / s.seconds) / math.ln2).abs();
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }
```

- [ ] **Step 4: 验证测试**

Run: `flutter test test/domain/metering/ev_calculator_test.dart`
Expected: 全部 PASS（旧的 Sunny 16 case：f/16 理论 t=1/128，吸附到 1/125，`|1/125 - 1/125| < 1/80` 真）。

- [ ] **Step 5: 跑全套测试**

Run: `flutter test`
Expected: 全部 PASS。Quick view 测试不依赖具体 pair 值。

- [ ] **Step 6: Commit**

```bash
git add lib/domain/metering/ev_calculator.dart test/domain/metering/ev_calculator_test.dart
git commit -m "feat(meter): suggestPairs 吸附到 ShutterSpeed.fullStops 整档"
```

---

## Task 6: QuickModeState.userPairOffset + controller 接口

**Files:**
- Modify: `lib/pages/meter/controller/meter_state.dart`
- Modify: `lib/pages/meter/controller/meter_controller.dart`
- Test: `test/pages/meter/meter_controller_test.dart`

- [ ] **Step 1: 追加状态测试（TDD）**

在 `test/pages/meter/meter_controller_test.dart` 的 `group('MeterController (regrouped state)', ...)` 内追加：

```dart
    test('userPairOffset 默认 null，quickSetPairOffset 写入', () {
      expect(c.state.quick.userPairOffset, isNull);
      c.quickSetPairOffset(2);
      expect(c.state.quick.userPairOffset, 2);
      c.quickSetPairOffset(-1);
      expect(c.state.quick.userPairOffset, -1);
    });

    test('quickResetPairOffset 清回 null', () {
      c.quickSetPairOffset(3);
      c.quickResetPairOffset();
      expect(c.state.quick.userPairOffset, isNull);
    });

    test('切 ISO/COMP/FILTER 不重置 userPairOffset', () {
      c.quickSetPairOffset(1);
      c.setIso(IsoValue(800));
      c.quickSetComp(EvStop.thirds(1));
      c.quickSetFilter(NdFilter.nd4);
      expect(c.state.quick.userPairOffset, 1);
    });
```

- [ ] **Step 2: 验证测试失败**

Run: `flutter test test/pages/meter/meter_controller_test.dart`
Expected: 编译失败，`userPairOffset` / `quickSetPairOffset` / `quickResetPairOffset` 未定义。

- [ ] **Step 3: 扩展 QuickModeState**

`lib/pages/meter/controller/meter_state.dart` 的 `QuickModeState` 改为：

```dart
@immutable
class QuickModeState {
  final EvStop comp;
  final NdFilter filter;
  final double? lockedEv;
  final MeterReading? metered;
  final int? userPairOffset;

  const QuickModeState({
    required this.comp,
    required this.filter,
    required this.lockedEv,
    required this.metered,
    required this.userPairOffset,
  });

  factory QuickModeState.initial() => const QuickModeState(
        comp: EvStop.zero,
        filter: NdFilter.none,
        lockedEv: null,
        metered: null,
        userPairOffset: null,
      );

  QuickModeState copyWith({
    EvStop? comp,
    NdFilter? filter,
    Object? lockedEv = _sentinel,
    Object? metered = _sentinel,
    Object? userPairOffset = _sentinel,
  }) {
    return QuickModeState(
      comp: comp ?? this.comp,
      filter: filter ?? this.filter,
      lockedEv:
          identical(lockedEv, _sentinel) ? this.lockedEv : lockedEv as double?,
      metered: identical(metered, _sentinel)
          ? this.metered
          : metered as MeterReading?,
      userPairOffset: identical(userPairOffset, _sentinel)
          ? this.userPairOffset
          : userPairOffset as int?,
    );
  }
}
```

- [ ] **Step 4: 加 controller 方法**

`lib/pages/meter/controller/meter_controller.dart` 在 `// ---- quick ----` 区块末尾追加：

```dart
  void quickSetPairOffset(int offset) =>
      _set(_state.copyWith(quick: _state.quick.copyWith(userPairOffset: offset)));

  void quickResetPairOffset() =>
      _set(_state.copyWith(quick: _state.quick.copyWith(userPairOffset: null)));
```

- [ ] **Step 5: 验证测试通过**

Run: `flutter test test/pages/meter/meter_controller_test.dart`
Expected: 全部 PASS。

Run: `flutter test`
Expected: 全部 PASS（QuickModeState 的 const 工厂签名变化由 `initial()` 兜底，其他调用方都走 copyWith）。

- [ ] **Step 6: Commit**

```bash
git add lib/pages/meter/controller/meter_state.dart lib/pages/meter/controller/meter_controller.dart test/pages/meter/meter_controller_test.dart
git commit -m "feat(meter): QuickModeState.userPairOffset + controller 接口"
```

---

## Task 7: DualScale 重写为双滚轮

**Files:**
- Modify: `lib/pages/meter/widgets/dual_scale.dart` — 全文替换
- Test: `test/pages/meter/widgets/dual_scale_test.dart` — 全文替换

- [ ] **Step 1: 重写 dual_scale 测试（TDD）**

替换 `test/pages/meter/widgets/dual_scale_test.dart` 全文为：

```dart
import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:film_go/pages/meter/widgets/dual_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<ExposurePair> _pairs() => [
      ExposurePair(aperture: Aperture(2.0), shutter: ShutterSpeed.seconds(1 / 500)),
      ExposurePair(aperture: Aperture(2.8), shutter: ShutterSpeed.seconds(1 / 250)),
      ExposurePair(aperture: Aperture(4.0), shutter: ShutterSpeed.seconds(1 / 125)),
      ExposurePair(aperture: Aperture(5.6), shutter: ShutterSpeed.seconds(1 / 60)),
      ExposurePair(aperture: Aperture(8.0), shutter: ShutterSpeed.seconds(1 / 30)),
    ];

Widget _host({
  required List<ExposurePair> pairs,
  required int activeIndex,
  required ValueChanged<int> onIndexChanged,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 320,
          child: DualScale(
            pairs: pairs,
            activeIndex: activeIndex,
            onIndexChanged: onIndexChanged,
          ),
        ),
      ),
    );

void main() {
  testWidgets('渲染时中心档可见（带 highlight 文本）', (tester) async {
    await tester.pumpWidget(_host(
      pairs: _pairs(),
      activeIndex: 2,
      onIndexChanged: (_) {},
    ));
    await tester.pumpAndSettle();
    expect(find.text('1/125'), findsOneWidget);
    expect(find.text('f/4'), findsOneWidget);
  });

  testWidgets('pairs 为空时显示占位 —', (tester) async {
    await tester.pumpWidget(_host(
      pairs: const [],
      activeIndex: 0,
      onIndexChanged: (_) {},
    ));
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('外部传入新 activeIndex 时两列都 animate 过去', (tester) async {
    final pairs = _pairs();
    int active = 2;
    late StateSetter setter;
    await tester.pumpWidget(StatefulBuilder(
      builder: (ctx, setState) {
        setter = setState;
        return _host(
          pairs: pairs,
          activeIndex: active,
          onIndexChanged: (_) {},
        );
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('1/125'), findsOneWidget);

    setter(() => active = 0);
    await tester.pumpAndSettle();
    expect(find.text('1/500'), findsOneWidget);
    expect(find.text('f/2'), findsOneWidget);
  });

  testWidgets('滚动左列触发 onIndexChanged，并把右列同步滚到该 index',
      (tester) async {
    final pairs = _pairs();
    final notifications = <int>[];
    await tester.pumpWidget(_host(
      pairs: pairs,
      activeIndex: 2,
      onIndexChanged: notifications.add,
    ));
    await tester.pumpAndSettle();

    // 两列 ListWheelScrollView，深度优先遍历下左列在 first。
    final wheels = find.byType(ListWheelScrollView);
    expect(wheels, findsNWidgets(2));

    // 上滑（手指上移）= 列表往后翻 = index 增加
    await tester.drag(wheels.first, const Offset(0, -64));
    await tester.pumpAndSettle();

    expect(notifications, isNotEmpty);
    expect(notifications.last, greaterThan(2));
  });
}
```

- [ ] **Step 2: 验证测试失败**

Run: `flutter test test/pages/meter/widgets/dual_scale_test.dart`
Expected: FAIL，`DualScale` 旧 API（`highlightIndex`）不再匹配。

- [ ] **Step 3: 重写 DualScale**

替换 `lib/pages/meter/widgets/dual_scale.dart` 全文为：

```dart
import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:flutter/material.dart';

/// 快速测光左侧的双列竖滚轮：左列快门、右列光圈。
///
/// 两列共享同一个 index 空间（pairs 的索引）。任一列滚动会触发
/// [onIndexChanged] 并把另一列以动画同步到同一 index；父层把 [activeIndex]
/// 重新喂回来时两列都 animate 到该位置。
class DualScale extends StatefulWidget {
  const DualScale({
    super.key,
    required this.pairs,
    required this.activeIndex,
    required this.onIndexChanged,
    this.itemExtent = 32,
  });

  final List<ExposurePair> pairs;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final double itemExtent;

  @override
  State<DualScale> createState() => _DualScaleState();
}

class _DualScaleState extends State<DualScale> {
  late FixedExtentScrollController _leftCtrl;
  late FixedExtentScrollController _rightCtrl;
  bool _syncing = false;

  int get _clampedActive {
    if (widget.pairs.isEmpty) return 0;
    return widget.activeIndex.clamp(0, widget.pairs.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _leftCtrl = FixedExtentScrollController(initialItem: _clampedActive);
    _rightCtrl = FixedExtentScrollController(initialItem: _clampedActive);
  }

  @override
  void didUpdateWidget(covariant DualScale old) {
    super.didUpdateWidget(old);
    if (widget.pairs.isEmpty) return;
    final target = _clampedActive;
    final futures = <Future<void>>[];
    if (_leftCtrl.hasClients && _leftCtrl.selectedItem != target) {
      futures.add(_leftCtrl.animateToItem(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ));
    }
    if (_rightCtrl.hasClients && _rightCtrl.selectedItem != target) {
      futures.add(_rightCtrl.animateToItem(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ));
    }
    if (futures.isNotEmpty) {
      _syncing = true;
      Future.wait(futures).whenComplete(() => _syncing = false);
    }
  }

  @override
  void dispose() {
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  void _onLeft(int i) => _onAny(i, other: _rightCtrl);
  void _onRight(int i) => _onAny(i, other: _leftCtrl);

  void _onAny(int i, {required FixedExtentScrollController other}) {
    if (_syncing) return;
    if (i == widget.activeIndex) return;
    widget.onIndexChanged(i);
    if (other.hasClients && other.selectedItem != i) {
      _syncing = true;
      other
          .animateToItem(
            i,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pairs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('—', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('—', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                height: widget.itemExtent,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _Wheel(
                controller: _leftCtrl,
                itemExtent: widget.itemExtent,
                count: widget.pairs.length,
                builder: (i) => widget.pairs[i].shutter.display,
                onChanged: _onLeft,
                activeIndex: _clampedActive,
              ),
            ),
            Expanded(
              child: _Wheel(
                controller: _rightCtrl,
                itemExtent: widget.itemExtent,
                count: widget.pairs.length,
                builder: (i) => widget.pairs[i].aperture.display,
                onChanged: _onRight,
                activeIndex: _clampedActive,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.itemExtent,
    required this.count,
    required this.builder,
    required this.onChanged,
    required this.activeIndex,
  });

  final FixedExtentScrollController controller;
  final double itemExtent;
  final int count;
  final String Function(int) builder;
  final ValueChanged<int> onChanged;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      perspective: 0.001,
      diameterRatio: 100,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) {
          final highlight = i == activeIndex;
          final style = highlight
              ? base?.copyWith(fontWeight: FontWeight.w800)
              : base?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant);
          return Center(child: Text(builder(i), style: style));
        },
      ),
    );
  }
}
```

- [ ] **Step 4: 验证测试通过**

Run: `flutter test test/pages/meter/widgets/dual_scale_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/pages/meter/widgets/dual_scale.dart test/pages/meter/widgets/dual_scale_test.dart
git commit -m "feat(meter): DualScale 重写为双滚轮，支持手动选择曝光对"
```

---

## Task 8: QuickMeterView 接 activeIndex 与回调

**Files:**
- Modify: `lib/pages/meter/quick/quick_meter_view.dart`

> QuickMeterView 内部已经在每帧重算 pairs；新增 `pairIndex` 计算并接到 DualScale。

- [ ] **Step 1: 修改 QuickMeterView**

把 `lib/pages/meter/quick/quick_meter_view.dart` 的 build 体改为：

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(meterControllerProvider);
    final s = c.state;
    final iso = s.shared.iso;

    final liveEv100 = s.quick.lockedEv ?? s.quick.metered?.ev;
    final evEff = liveEv100 == null
        ? null
        : liveEv100 +
            (math.log(iso.value / 100) / math.ln2) -
            s.quick.comp.stops -
            s.quick.filter.stops;
    final pairs = evEff == null
        ? const <ExposurePair>[]
        : EvCalculator.suggestPairs(ev: evEff, iso: iso.value);
    final center = pairs.isEmpty ? 0 : pairs.length ~/ 2;
    final offset = s.quick.userPairOffset ?? 0;
    final activeIndex = pairs.isEmpty
        ? 0
        : (center + offset).clamp(0, pairs.length - 1);

    final ev100Int =
        (liveEv100 ?? 10).round().clamp(QuickDrum.evMin, QuickDrum.evMax);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 64, 12, 12),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: DualScale(
                      pairs: pairs,
                      activeIndex: activeIndex,
                      onIndexChanged: (i) =>
                          c.quickSetPairOffset(i - center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: preview ?? const _PreviewPlaceholder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        MeasureIconButton(
                          locked: s.quick.lockedEv != null,
                          onTap: () {
                            if (s.quick.lockedEv != null) {
                              c.quickUnlock();
                            } else {
                              c.quickLock();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: QuickDrum(
                ev100: ev100Int,
                iso: iso,
                comp: s.quick.comp,
                filter: s.quick.filter,
                onEv100Changed: (v) => c.quickLockTo(v.toDouble()),
                onIsoChanged: c.setIso,
                onCompChanged: c.quickSetComp,
                onFilterChanged: c.quickSetFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

（删掉旧的 `highlightIndex` 变量。）

- [ ] **Step 2: 跑全套测试**

Run: `flutter test`
Expected: 全部 PASS。`quick_meter_view_test.dart` 不关心 DualScale 细节。

- [ ] **Step 3: Commit**

```bash
git add lib/pages/meter/quick/quick_meter_view.dart
git commit -m "feat(meter): QuickMeterView 接 DualScale 双滚轮"
```

---

## Task 9: 专业测光拍照修复（stop/start + gallery 保存）

**Files:**
- Modify: `lib/pages/meter/meter_page.dart`
- Modify: `lib/pages/meter/pro/pro_meter_view.dart`（SnackBar 失败提示）

- [ ] **Step 1: 修 capture 闭包与 saveToGallery**

`lib/pages/meter/meter_page.dart` 顶部 import 追加：

```dart
import 'package:image_gallery_saver/image_gallery_saver.dart';
```

把 `_bootstrap()` 中创建 `_capture` 的代码（约 56-69 行）替换为：

```dart
      _capture = CameraCaptureService(
        capture: () async {
          final controller = _camera.controller;
          if (controller == null) {
            throw StateError('相机未初始化');
          }
          // takePicture() 与 image stream 互斥：先停帧流，拍完恢复。
          await _camera.stop();
          try {
            final file = await controller.takePicture();
            return Uint8List.fromList(await file.readAsBytes());
          } finally {
            await _camera.start();
          }
        },
        saveToGallery: (bytes, name) async {
          await ImageGallerySaver.saveImage(
            bytes,
            name: name,
            quality: 90,
            isReturnImagePathOfIOS: true,
          );
        },
      );
```

- [ ] **Step 2: Pro 视图加失败提示**

`lib/pages/meter/pro/pro_meter_view.dart` 的 `_onShutter` 改为：

```dart
  Future<void> _onShutter(ExposurePair? pair) async {
    final svc = widget.captureService;
    if (svc == null || pair == null) return;
    setState(() => _capturing = true);
    try {
      final c = ref.read(meterControllerProvider);
      await svc.captureWithWatermark(
        WatermarkData(
          iso: 'ISO ${c.state.shared.iso.value}',
          shutter: pair.shutter.display,
          aperture: pair.aperture.display,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }
```

- [ ] **Step 3: 跑全套测试**

Run: `flutter test`
Expected: 全部 PASS。`pro_meter_view_test.dart` 用 spy CaptureService，不走真实闭包；`meter_page_smoke_test.dart` 不触发拍照按钮，安全。

- [ ] **Step 4: 真机/模拟器烟测**

> 这一步**必须**手动执行——拍照闭包接的是真实 `camera` 插件 + `image_gallery_saver`，单测覆盖不到。

Run: `flutter run`

测试步骤：
1. 进入测光页 → 切到「专业」
2. 等到底部出现一对快门/光圈读数
3. 点中央快门按钮
4. 验证：按钮转 progress → 取景画面短暂停（≤1s）→ 恢复实时取景
5. 打开系统相册，应有一张新 JPEG，右下角带 `YYYY-MM-DD HH:MM` + `ISO/快门/光圈` 双行水印
6. 失败路径：撤销相册权限后再拍 → 屏幕下方应出现 SnackBar「拍照失败：...」，且取景未挂死

确认通过后再 commit。

- [ ] **Step 5: Commit**

```bash
git add lib/pages/meter/meter_page.dart lib/pages/meter/pro/pro_meter_view.dart
git commit -m "fix(meter): Pro 拍照修复 (stop/start image stream + gallery 保存)"
```

---

## Task 10: 真机烟测 + 收尾

- [ ] **Step 1: 跑一遍全套测试 + 静态分析**

```bash
flutter test
flutter analyze
```

Expected: tests 全 PASS；analyze 无 error，warning 控制在原有水平（不引入新 warning）。

- [ ] **Step 2: 真机 / 模拟器看视觉**

```bash
flutter run
```

人眼检查：
- Quick 页：背景是 `paperWhite` 暖纸感（不是纯白），滚轮高亮带是 `surfaceHighLight` 略深一档
- Pro 页：取景背景仍黑（`charcoalBlack`），底部刻度尺与读数字色是 paperWhite（不是冷白），spot 框为 `spotHighlight` 暖黄
- DualScale 双滚轮可独立用手指上下滑，松手后另一列追平；测光读数缓变时两列同步漂移到新中点

- [ ] **Step 3: （可选）补 README 截图 / changelog**

不要求。

---

## 任务依赖图

```
1 (colors) ──┬─> 2 (theme) ──> 3 (pro 配色迁移)
             │
4 (shutter.fullStops) ──> 5 (suggestPairs snap)
                                │
6 (state + controller) ─────────┼─> 7 (DualScale 重写) ──> 8 (QuickMeterView 接线)
                                │
9 (拍照修复) ──── 独立
                                              │
                                              v
                                       10 (烟测收尾)
```

并行机会：Task 1-3（配色）、Task 4-5+6-8（快测）、Task 9（拍照）三条链彼此独立，可分别派 subagent。

---

## 风险与回滚

- Task 5 阈值 0.5 stop：若发现推荐对数过少（如 EV ≥ 18 时只剩 1-2 对），把 `tolerance` 调到 0.75 重跑 ev_calculator 测试。
- Task 7 ListWheelScrollView 在窄宽度下 perspective 偏差视觉不佳：可在 Step 3 里把 `diameterRatio` 调高到 200 弱化倾斜。
- Task 9 `ImageGallerySaver.saveImage` 失败：Android 13+ 需要 `READ_MEDIA_IMAGES` 权限；若烟测时 SnackBar 弹出权限相关错误，到 Task 11（不在此 plan 内）处理 manifest + 申请流程。本次 plan 范围只到「调用通了 API」。
- 任一 task 失败：单 task 内的 commit 是原子的，`git revert <hash>` 即可回滚单步而不影响其他链。
