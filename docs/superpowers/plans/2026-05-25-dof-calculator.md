# 景深 / 超焦距计算器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `lib/pages/calc/calc_page.dart` 从空占位升级成「景深 / 超焦距」可用页：4 个横向刻度参数（对焦距离/焦距/光圈/画幅）+ 顶部胶片卷轴可视化 + 一键「= H」吸到超焦距。

**Architecture:** Domain 复用现有 `DepthOfField.compute`，新增 `FilmFormat` 枚举提供画幅 → 弥散圆查表。Presentation 用 Riverpod `ChangeNotifierProvider`（与 `MeterController` 同模式）暴露 `DofController`。所有横向滚轮基于 `PageView + viewportFraction` 实现，胶片卷轴可视化用单 `CustomPainter` 完成。

**Tech Stack:** Flutter 3.x / Dart 3 / `flutter_riverpod` / `flutter_test` / project 现有 `AppColors` + `JetBrains Mono`。

**Spec reference:** `docs/superpowers/specs/2026-05-25-dof-calculator-design.md`

**Project conventions（每个文件都按这个写）：**
- 单引号字符串、`require_trailing_commas`、`prefer_const_constructors`
- 强类型 `strict-casts: true`，公开函数 `always_declare_return_types`
- 测试 `group`/`test` 用中文描述，与 `test/domain/dof/depth_of_field_test.dart` 一致
- Controller 用 `ChangeNotifier` + Riverpod `ChangeNotifierProvider`（参照 `lib/pages/meter/controller/meter_controller.dart:217`）
- 颜色 token 走 `Theme.of(context).colorScheme` 或 `AppColors.*`，禁止硬编码 `Colors.xxx`

**通用命令：**
- 单文件跑测：`flutter test test/<path>.dart`
- 全量测：`flutter test`
- Lint：`flutter analyze`
- 真机：`./scripts/build_android.sh --run`

---

## File Structure

**新增**

| 文件 | 责任 |
|---|---|
| `lib/domain/dof/film_format.dart` | `FilmFormat` 枚举 + cocMm 查表 |
| `lib/pages/calc/controller/dof_state.dart` | `DofState` 不可变 + 派生 `result` / `focusMeters` / `aperture` / `cocMm` |
| `lib/pages/calc/controller/dof_controller.dart` | `DofController` (ChangeNotifier) + Riverpod provider |
| `lib/pages/calc/widgets/horizontal_scale.dart` | 通用横向滚动刻度尺 |
| `lib/pages/calc/widgets/format_chip_row.dart` | 4 个画幅 chip 单选 |
| `lib/pages/calc/widgets/film_strip_dof_view.dart` | 顶部胶片卷轴可视化（CustomPainter） |
| `lib/pages/calc/widgets/dof_param_row.dart` | 一行 = label + value + HorizontalScale（含可选 `=H` chip） |

**修改**

| 文件 | 责任 |
|---|---|
| `lib/pages/calc/calc_page.dart` | 占位 → 实装页面，装配 5 段（visualizer + 4 param + c row） |

**测试新增**

| 文件 |
|---|
| `test/domain/dof/film_format_test.dart` |
| `test/pages/calc/controller/dof_controller_test.dart` |
| `test/pages/calc/widgets/horizontal_scale_test.dart` |
| `test/pages/calc/widgets/format_chip_row_test.dart` |
| `test/pages/calc/widgets/film_strip_dof_view_test.dart` |
| `test/pages/calc/widgets/dof_param_row_test.dart` |
| `test/pages/calc/calc_page_test.dart` |

---

## Task 1: FilmFormat 枚举

**Files:**
- Create: `lib/domain/dof/film_format.dart`
- Test: `test/domain/dof/film_format_test.dart`

- [ ] **Step 1: 写失败测试**

`test/domain/dof/film_format_test.dart`：

```dart
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
```

- [ ] **Step 2: 跑测确认 fail**

Run: `flutter test test/domain/dof/film_format_test.dart`
Expected: FAIL，`Target of URI doesn't exist`

- [ ] **Step 3: 实装**

`lib/domain/dof/film_format.dart`：

```dart
/// 胶卷画幅及对应弥散圆 c 值（mm）。
///
/// c 取自常用工程经验：35mm 民用 0.030mm；中画幅按对角线比例近似；
/// 4×5 取大画幅常用 0.150mm。详见 spec §3.2。
enum FilmFormat {
  f135(label: '135', cocMm: 0.030),
  f6x6(label: '6×6', cocMm: 0.060),
  f6x7(label: '6×7', cocMm: 0.066),
  f4x5(label: '4×5', cocMm: 0.150);

  const FilmFormat({required this.label, required this.cocMm});

  final String label;
  final double cocMm;
}
```

- [ ] **Step 4: 跑测确认 pass**

Run: `flutter test test/domain/dof/film_format_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 5: Lint + commit**

```bash
flutter analyze lib/domain/dof/film_format.dart test/domain/dof/film_format_test.dart
git add lib/domain/dof/film_format.dart test/domain/dof/film_format_test.dart
git commit -m "feat(dof): add FilmFormat enum + coc lookup"
```

---

## Task 2: DofState + DofController

**Files:**
- Create: `lib/pages/calc/controller/dof_state.dart`
- Create: `lib/pages/calc/controller/dof_controller.dart`
- Test: `test/pages/calc/controller/dof_controller_test.dart`

- [ ] **Step 1: 写失败测试**

`test/pages/calc/controller/dof_controller_test.dart`：

```dart
import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/pages/calc/controller/dof_controller.dart';
import 'package:film_go/pages/calc/controller/dof_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DofState defaults', () {
    final s = DofState.initial;

    test('默认 focusDistIndex=7 → 5m', () {
      expect(s.focusDistIndex, 7);
      expect(s.focusMeters, 5);
    });

    test('默认焦距 50mm、光圈 f/8、画幅 135', () {
      expect(s.focalLengthMm, 50);
      expect(s.aperture.fNumber, 8);
      expect(s.format, FilmFormat.f135);
      expect(s.cocMm, 0.030);
    });

    test('focusSteps 长度 16，首 0.3m、末 ∞', () {
      expect(DofState.focusSteps.length, 16);
      expect(DofState.focusSteps.first, 0.3);
      expect(DofState.focusSteps.last, double.infinity);
    });

    test('默认 result：近景 < 5 < 远景，超焦距 ~10.5m', () {
      final r = s.result;
      expect(r.nearMeters, lessThan(5));
      expect(r.farMeters, isNotNull);
      expect(r.farMeters, greaterThan(5));
      expect(r.hyperfocalMeters, closeTo(10.47, 0.1));
    });

    test('对焦于 ∞ 时 far=null、near=H', () {
      final inf = s.copyWith(focusDistIndex: DofState.focusSteps.length - 1);
      expect(inf.focusMeters, double.infinity);
      expect(inf.result.farMeters, isNull);
      expect(inf.result.nearMeters, closeTo(10.47, 0.1));
    });
  });

  group('DofController', () {
    late DofController c;
    setUp(() => c = DofController());

    test('setFocalLength 更新焦距并刷新 result', () {
      final h0 = c.state.result.hyperfocalMeters;
      c.setFocalLength(100);
      expect(c.state.focalLengthMm, 100);
      expect(c.state.result.hyperfocalMeters, isNot(closeTo(h0, 0.001)));
    });

    test('setApertureIndex 切到 f/16 → 超焦距变小', () {
      final hAt8 = c.state.result.hyperfocalMeters;
      c.setApertureIndex(8); // Aperture.fullStops[8] = f/16
      expect(c.state.aperture.fNumber, 16);
      expect(c.state.result.hyperfocalMeters, lessThan(hAt8));
    });

    test('setFormat 切到 6×6 → 弥散圆变大、超焦距变小', () {
      final h0 = c.state.result.hyperfocalMeters;
      c.setFormat(FilmFormat.f6x6);
      expect(c.state.cocMm, 0.060);
      expect(c.state.result.hyperfocalMeters, lessThan(h0));
    });

    test('snapToHyperfocal: H<100m 时挑最接近档', () {
      // 默认 H ≈ 10.47m → focusSteps 第 9 项 = 10
      c.setFocusDistIndex(0);
      c.snapToHyperfocal();
      expect(DofState.focusSteps[c.state.focusDistIndex], 10);
    });

    test('snapToHyperfocal: H>100m 时跳到 ∞ 档', () {
      // 焦距 200mm + f/2.8 → H ≈ 476m
      c.setFocalLength(200);
      c.setApertureIndex(3); // f/2.8
      c.snapToHyperfocal();
      expect(c.state.focusMeters, double.infinity);
    });

    test('change 调 notifyListeners', () {
      var count = 0;
      c.addListener(() => count++);
      c.setFocalLength(85);
      c.setApertureIndex(4);
      c.setFormat(FilmFormat.f6x7);
      expect(count, 3);
    });
  });
}
```

- [ ] **Step 2: 跑测确认 fail**

Run: `flutter test test/pages/calc/controller/dof_controller_test.dart`
Expected: FAIL，URI 不存在

- [ ] **Step 3: 实装 state**

`lib/pages/calc/controller/dof_state.dart`：

```dart
import 'package:film_go/domain/dof/depth_of_field.dart';
import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:meta/meta.dart';

/// 景深页输入与派生计算结果。所有派生 getter 都是 pure。
@immutable
class DofState {
  const DofState({
    required this.focusDistIndex,
    required this.focalLengthMm,
    required this.apertureIndex,
    required this.format,
  });

  /// 16 档镜头标尺距离（米），末位为 `double.infinity`。
  static const List<double> focusSteps = <double>[
    0.3, 0.5, 0.7, 1, 1.5, 2, 3, 5, 7, 10, 15, 20, 30, 50, 100,
    double.infinity,
  ];

  /// 默认：5m / 50mm / f/8 / 135。
  static const DofState initial = DofState(
    focusDistIndex: 7,
    focalLengthMm: 50,
    apertureIndex: 6,
    format: FilmFormat.f135,
  );

  final int focusDistIndex;
  final int focalLengthMm;
  final int apertureIndex;
  final FilmFormat format;

  double get focusMeters => focusSteps[focusDistIndex];
  Aperture get aperture => Aperture.fullStops[apertureIndex];
  double get cocMm => format.cocMm;

  DofResult get result {
    final h = DepthOfField.hyperfocalMeters(
      focalLengthMm: focalLengthMm.toDouble(),
      aperture: aperture,
      circleOfConfusionMm: cocMm,
    );
    if (!focusMeters.isFinite) {
      return DofResult(
        nearMeters: h,
        farMeters: null,
        hyperfocalMeters: h,
      );
    }
    return DepthOfField.compute(
      focalLengthMm: focalLengthMm.toDouble(),
      aperture: aperture,
      circleOfConfusionMm: cocMm,
      focusDistanceMeters: focusMeters,
    );
  }

  DofState copyWith({
    int? focusDistIndex,
    int? focalLengthMm,
    int? apertureIndex,
    FilmFormat? format,
  }) {
    return DofState(
      focusDistIndex: focusDistIndex ?? this.focusDistIndex,
      focalLengthMm: focalLengthMm ?? this.focalLengthMm,
      apertureIndex: apertureIndex ?? this.apertureIndex,
      format: format ?? this.format,
    );
  }
}
```

- [ ] **Step 4: 实装 controller**

`lib/pages/calc/controller/dof_controller.dart`：

```dart
import 'package:film_go/pages/calc/controller/dof_state.dart';
import 'package:film_go/domain/dof/film_format.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DofController extends ChangeNotifier {
  DofController() : _state = DofState.initial;

  DofState _state;
  DofState get state => _state;

  void _set(DofState s) {
    _state = s;
    notifyListeners();
  }

  void setFocusDistIndex(int i) {
    final clamped = i.clamp(0, DofState.focusSteps.length - 1);
    _set(_state.copyWith(focusDistIndex: clamped));
  }

  void setFocalLength(int mm) {
    final clamped = mm.clamp(8, 500);
    _set(_state.copyWith(focalLengthMm: clamped));
  }

  void setApertureIndex(int i) {
    // Aperture.fullStops 长度 13
    final clamped = i.clamp(0, 12);
    _set(_state.copyWith(apertureIndex: clamped));
  }

  void setFormat(FilmFormat f) => _set(_state.copyWith(format: f));

  /// 把对焦距离吸到当前 H 最接近的档；H>100m 直接选 ∞。
  void snapToHyperfocal() {
    final h = _state.result.hyperfocalMeters;
    if (h > 100) {
      _set(
        _state.copyWith(focusDistIndex: DofState.focusSteps.length - 1),
      );
      return;
    }
    var bestIndex = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < DofState.focusSteps.length - 1; i++) {
      final d = (DofState.focusSteps[i] - h).abs();
      if (d < bestDiff) {
        bestDiff = d;
        bestIndex = i;
      }
    }
    _set(_state.copyWith(focusDistIndex: bestIndex));
  }
}

final dofControllerProvider =
    ChangeNotifierProvider<DofController>((ref) => DofController());
```

- [ ] **Step 5: 跑测确认 pass**

Run: `flutter test test/pages/calc/controller/dof_controller_test.dart`
Expected: PASS, 11 tests

- [ ] **Step 6: Lint + commit**

```bash
flutter analyze lib/pages/calc/controller test/pages/calc/controller
git add lib/pages/calc/controller test/pages/calc/controller
git commit -m "feat(calc): add DofState + DofController with snap-to-hyperfocal"
```

---

## Task 3: HorizontalScale 通用横向滚轮

**Files:**
- Create: `lib/pages/calc/widgets/horizontal_scale.dart`
- Test: `test/pages/calc/widgets/horizontal_scale_test.dart`

设计要点（spec §4.2）：
- 用 `PageView.builder` + `PageController(viewportFraction = itemExtent / availableWidth)`
- `LayoutBuilder` 拿宽度，运行时算 viewportFraction（最低 0.15）
- 中心三角指示器（顶层 Stack，颜色 spotHighlight）
- 同步标志 `_syncing` 防双向回调死循环（沿用 DualScale 写法）

- [ ] **Step 1: 写失败测试**

`test/pages/calc/widgets/horizontal_scale_test.dart`：

```dart
import 'package:film_go/pages/calc/widgets/horizontal_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );

void main() {
  group('HorizontalScale', () {
    testWidgets('渲染当前 active label 加粗、旁侧弱化', (t) async {
      await t.pumpWidget(_wrap(HorizontalScale(
        labels: const ['48', '49', '50', '51', '52'],
        activeIndex: 2,
        onIndexChanged: (_) {},
      )));
      await t.pumpAndSettle();
      // active 文本必定出现
      expect(find.text('50'), findsOneWidget);
      // 至少有一个旁侧标签（49 或 51）
      expect(find.text('49').evaluate().isNotEmpty || find.text('51').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('activeIndex 变化 → 内部 controller 跟到新位置', (t) async {
      var notified = -1;
      var active = 2;
      await t.pumpWidget(_wrap(StatefulBuilder(
        builder: (ctx, setSB) => HorizontalScale(
          labels: const ['a', 'b', 'c', 'd', 'e'],
          activeIndex: active,
          onIndexChanged: (i) => notified = i,
        ),
      )));
      await t.pumpAndSettle();
      // 重建到 index 4
      active = 4;
      await t.pumpWidget(_wrap(HorizontalScale(
        labels: const ['a', 'b', 'c', 'd', 'e'],
        activeIndex: active,
        onIndexChanged: (i) => notified = i,
      )));
      await t.pumpAndSettle();
      expect(find.text('e'), findsOneWidget);
      // 同步动画期间不回调
      expect(notified, -1);
    });

    testWidgets('用户 fling → onIndexChanged 被调', (t) async {
      var notified = -1;
      await t.pumpWidget(_wrap(HorizontalScale(
        labels: const ['a', 'b', 'c', 'd', 'e'],
        activeIndex: 2,
        onIndexChanged: (i) => notified = i,
      )));
      await t.pumpAndSettle();
      // 从中心位置向左 fling 一段
      await t.fling(find.text('c'), const Offset(-200, 0), 1000);
      await t.pumpAndSettle();
      expect(notified, isNot(-1));
    });
  });
}
```

- [ ] **Step 2: 跑测确认 fail**

Run: `flutter test test/pages/calc/widgets/horizontal_scale_test.dart`
Expected: FAIL，URI 不存在

- [ ] **Step 3: 实装**

`lib/pages/calc/widgets/horizontal_scale.dart`：

```dart
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 通用横向滚动刻度尺。
///
/// - `PageView.builder` + `viewportFraction = itemExtent / 可用宽`
/// - 中心三角指示器（spotHighlight）
/// - active item 字号/字重高亮
/// - 父层换 activeIndex → didUpdateWidget animateToPage
class HorizontalScale extends StatefulWidget {
  const HorizontalScale({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onIndexChanged,
    this.itemExtent = 56,
    this.height = 56,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final double itemExtent;
  final double height;

  @override
  State<HorizontalScale> createState() => _HorizontalScaleState();
}

class _HorizontalScaleState extends State<HorizontalScale> {
  PageController? _ctrl;
  double? _builtForWidth;
  bool _syncing = false;

  int get _clamped =>
      widget.activeIndex.clamp(0, widget.labels.length - 1);

  void _ensureController(double width) {
    if (_ctrl != null && _builtForWidth == width) return;
    _ctrl?.dispose();
    final raw = widget.itemExtent / width;
    final vp = raw.clamp(0.15, 1.0);
    _ctrl = PageController(
      viewportFraction: vp.toDouble(),
      initialPage: _clamped,
    );
    _builtForWidth = width;
  }

  @override
  void didUpdateWidget(covariant HorizontalScale old) {
    super.didUpdateWidget(old);
    final c = _ctrl;
    if (c == null || !c.hasClients) return;
    final target = _clamped;
    final current = c.page?.round() ?? c.initialPage;
    if (_syncing || current == target) return;
    _syncing = true;
    c
        .animateToPage(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .whenComplete(() => _syncing = false);
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    if (_syncing) return;
    if (i == widget.activeIndex) return;
    widget.onIndexChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) {
      return SizedBox(height: widget.height);
    }
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          _ensureController(c.maxWidth);
          final active = _clamped;
          return Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _ctrl,
                onPageChanged: _onPageChanged,
                physics: const PageScrollPhysics(),
                itemCount: widget.labels.length,
                itemBuilder: (context, i) {
                  final on = i == active;
                  final style = TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: on ? 16 : 13,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w400,
                    color: on ? cs.onSurface : cs.onSurfaceVariant,
                  );
                  return Center(child: Text(widget.labels[i], style: style));
                },
              ),
              IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: CustomPaint(
                      size: const Size(12, 6),
                      painter: _DownTrianglePainter(AppColors.spotHighlight),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DownTrianglePainter extends CustomPainter {
  _DownTrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DownTrianglePainter old) => old.color != color;
}
```

- [ ] **Step 4: 跑测确认 pass**

Run: `flutter test test/pages/calc/widgets/horizontal_scale_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 5: Lint + commit**

```bash
flutter analyze lib/pages/calc/widgets/horizontal_scale.dart test/pages/calc/widgets/horizontal_scale_test.dart
git add lib/pages/calc/widgets/horizontal_scale.dart test/pages/calc/widgets/horizontal_scale_test.dart
git commit -m "feat(calc): add HorizontalScale page-view scroller"
```

---

## Task 4: FormatChipRow

**Files:**
- Create: `lib/pages/calc/widgets/format_chip_row.dart`
- Test: `test/pages/calc/widgets/format_chip_row_test.dart`

- [ ] **Step 1: 写失败测试**

`test/pages/calc/widgets/format_chip_row_test.dart`：

```dart
import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/pages/calc/widgets/format_chip_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FormatChipRow', () {
    testWidgets('渲染 4 个 label', (t) async {
      await t.pumpWidget(_wrap(FormatChipRow(
        active: FilmFormat.f135,
        onChanged: (_) {},
      )));
      expect(find.text('135'), findsOneWidget);
      expect(find.text('6×6'), findsOneWidget);
      expect(find.text('6×7'), findsOneWidget);
      expect(find.text('4×5'), findsOneWidget);
    });

    testWidgets('点未选中的 chip 触发 onChanged', (t) async {
      FilmFormat? picked;
      await t.pumpWidget(_wrap(FormatChipRow(
        active: FilmFormat.f135,
        onChanged: (f) => picked = f,
      )));
      await t.tap(find.text('6×7'));
      expect(picked, FilmFormat.f6x7);
    });

    testWidgets('点已选中 chip 不重复触发', (t) async {
      var count = 0;
      await t.pumpWidget(_wrap(FormatChipRow(
        active: FilmFormat.f135,
        onChanged: (_) => count++,
      )));
      await t.tap(find.text('135'));
      expect(count, 0);
    });
  });
}
```

- [ ] **Step 2: 跑测确认 fail**

Run: `flutter test test/pages/calc/widgets/format_chip_row_test.dart`
Expected: FAIL

- [ ] **Step 3: 实装**

`lib/pages/calc/widgets/format_chip_row.dart`：

```dart
import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 4 个画幅 chip 平铺单选。选中：spotHighlight 底 + charcoal 字。
class FormatChipRow extends StatelessWidget {
  const FormatChipRow({
    super.key,
    required this.active,
    required this.onChanged,
  });

  final FilmFormat active;
  final ValueChanged<FilmFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final f in FilmFormat.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Chip(
                label: f.label,
                selected: f == active,
                onTap: () {
                  if (f == active) return;
                  onChanged(f);
                },
                cs: cs,
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.spotHighlight : cs.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                color: selected
                    ? AppColors.charcoalBlack
                    : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测确认 pass**

Run: `flutter test test/pages/calc/widgets/format_chip_row_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 5: Lint + commit**

```bash
flutter analyze lib/pages/calc/widgets/format_chip_row.dart test/pages/calc/widgets/format_chip_row_test.dart
git add lib/pages/calc/widgets/format_chip_row.dart test/pages/calc/widgets/format_chip_row_test.dart
git commit -m "feat(calc): add FormatChipRow film-format selector"
```

---

## Task 5: FilmStripDofView 胶片卷轴可视化

**Files:**
- Create: `lib/pages/calc/widgets/film_strip_dof_view.dart`
- Test: `test/pages/calc/widgets/film_strip_dof_view_test.dart`

设计要点（spec §4.1）：
- 上下齿孔行 height=16，各 24 个 8×8 描边正方形
- 中间 DoF 带 height=80，背景 `cs.surfaceContainerHighest`
- 三标记（near/focus/far），focus 加粗高亮 spotHighlight
- 摘要行 height=32：`H = X.Xm  ·  总景深 ≈ Y.Ym` （∞ 时显示 ∞）
- 横轴映射：`distToX` log scale，留右 8% 给 ∞ 区
- 数值格式化：< 10m 1 位小数，≥ 10m 取整

- [ ] **Step 1: 写失败测试**

`test/pages/calc/widgets/film_strip_dof_view_test.dart`：

```dart
import 'package:film_go/domain/dof/depth_of_field.dart';
import 'package:film_go/pages/calc/widgets/film_strip_dof_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, height: 160, child: child)),
    );

void main() {
  group('FilmStripDofView', () {
    testWidgets('渲染近/对焦/远文字与摘要，far 有限时无 ∞', (t) async {
      const result = DofResult(
        nearMeters: 2.5,
        farMeters: 8.4,
        hyperfocalMeters: 10.47,
      );
      await t.pumpWidget(_wrap(const FilmStripDofView(
        result: result,
        focusMeters: 5,
      )));
      expect(find.text('对焦点'), findsOneWidget);
      expect(find.text('近景深'), findsOneWidget);
      expect(find.text('远景深'), findsOneWidget);
      // 摘要含 H
      expect(find.textContaining('H ='), findsOneWidget);
      // ∞ 不应作为远景出现
      expect(find.text('∞'), findsNothing);
    });

    testWidgets('对焦于 ∞ + far=null → 远景显示 ∞、摘要含 ∞', (t) async {
      const result = DofResult(
        nearMeters: 10.47,
        farMeters: null,
        hyperfocalMeters: 10.47,
      );
      await t.pumpWidget(_wrap(const FilmStripDofView(
        result: result,
        focusMeters: double.infinity,
      )));
      // 至少有一个 ∞（远景标记 + 可能摘要里再来一个）
      expect(find.text('∞'), findsWidgets);
    });

    testWidgets('< 10m 距离保留 1 位小数，≥ 10m 取整', (t) async {
      const result = DofResult(
        nearMeters: 2.456,
        farMeters: 24.89,
        hyperfocalMeters: 30.0,
      );
      await t.pumpWidget(_wrap(const FilmStripDofView(
        result: result,
        focusMeters: 8.0,
      )));
      expect(find.textContaining('2.5'), findsWidgets);
      expect(find.textContaining('25'), findsWidgets);
    });
  });
}
```

- [ ] **Step 2: 跑测确认 fail**

Run: `flutter test test/pages/calc/widgets/film_strip_dof_view_test.dart`
Expected: FAIL

- [ ] **Step 3: 实装**

`lib/pages/calc/widgets/film_strip_dof_view.dart`：

```dart
import 'dart:math' as math;

import 'package:film_go/domain/dof/depth_of_field.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 顶部胶片卷轴 DoF 可视化。
///
/// 结构：上齿孔 16 / 中带 80 / 下齿孔 16 / 摘要 32 = 144 + 内边距 = 160 总高。
class FilmStripDofView extends StatelessWidget {
  const FilmStripDofView({
    super.key,
    required this.result,
    required this.focusMeters,
    this.minDist = 0.3,
    this.maxDist = 1000,
  });

  final DofResult result;
  final double focusMeters;
  final double minDist;
  final double maxDist;

  static String _fmt(double m) {
    if (!m.isFinite) return '∞';
    return m < 10 ? m.toStringAsFixed(1) : m.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final summary = result.farMeters == null
        ? 'H = ${_fmt(result.hyperfocalMeters)}m  ·  总景深 ≈ ∞'
        : 'H = ${_fmt(result.hyperfocalMeters)}m'
            '  ·  总景深 ≈ ${_fmt(result.farMeters! - result.nearMeters)}m';
    return SizedBox(
      height: 160,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _StripPainter(
                          result: result,
                          focusMeters: focusMeters,
                          minDist: minDist,
                          maxDist: maxDist,
                          bandColor: cs.surfaceContainerHighest,
                          dofColor: AppColors.spotHighlight.withOpacity(0.35),
                          markerColor: AppColors.spotHighlight,
                          tickColor: cs.onSurface,
                          outlineColor: cs.outlineVariant,
                        ),
                      ),
                    ),
                    _MarkerLabels(
                      result: result,
                      focusMeters: focusMeters,
                      minDist: minDist,
                      maxDist: maxDist,
                      width: c.maxWidth,
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                summary,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 横轴映射：log scale，超过 maxDist 或 ∞ → 落在右端 92% 之后。
double distToX(double m, double width,
    {required double minD, required double maxD}) {
  final usable = width * 0.92;
  if (!m.isFinite || m > maxD) return width - width * 0.04;
  final clamped = m.clamp(minD, maxD);
  final t = (math.log(clamped) - math.log(minD)) /
      (math.log(maxD) - math.log(minD));
  return t * usable;
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.result,
    required this.focusMeters,
    required this.minDist,
    required this.maxDist,
    required this.bandColor,
    required this.dofColor,
    required this.markerColor,
    required this.tickColor,
    required this.outlineColor,
  });

  final DofResult result;
  final double focusMeters;
  final double minDist;
  final double maxDist;
  final Color bandColor;
  final Color dofColor;
  final Color markerColor;
  final Color tickColor;
  final Color outlineColor;

  static const double _holeRow = 16;
  static const int _holeCount = 24;

  @override
  void paint(Canvas canvas, Size size) {
    // 上下齿孔
    _paintHoles(canvas, size, 0);
    _paintHoles(canvas, size, size.height - _holeRow);

    // 中间带底色
    final mid = Rect.fromLTWH(0, _holeRow, size.width, size.height - 2 * _holeRow);
    canvas.drawRect(mid, Paint()..color = bandColor);

    // ∞ 区斜纹（右 8%）
    final infRect = Rect.fromLTRB(size.width * 0.92, _holeRow, size.width,
        size.height - _holeRow);
    _paintHatch(canvas, infRect, outlineColor.withOpacity(0.4));

    // DoF 高亮带
    final near = distToX(result.nearMeters, size.width,
        minD: minDist, maxD: maxDist);
    final farRaw = result.farMeters ?? double.infinity;
    final far = distToX(farRaw, size.width, minD: minDist, maxD: maxDist);
    if (far > near) {
      final dofRect = Rect.fromLTRB(near, _holeRow, far, size.height - _holeRow);
      canvas.drawRect(dofRect, Paint()..color = dofColor);
    }

    // 三条刻度线：near / focus / far
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    final focusX = distToX(focusMeters, size.width,
        minD: minDist, maxD: maxDist);
    final focusPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 2;
    canvas.drawLine(Offset(near, _holeRow), Offset(near, size.height - _holeRow), tickPaint);
    canvas.drawLine(Offset(focusX, _holeRow), Offset(focusX, size.height - _holeRow), focusPaint);
    canvas.drawLine(Offset(far, _holeRow), Offset(far, size.height - _holeRow), tickPaint);
  }

  void _paintHoles(Canvas canvas, Size size, double topY) {
    final paint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final spacing = size.width / _holeCount;
    const sq = 8.0;
    final y = topY + (_holeRow - sq) / 2;
    for (var i = 0; i < _holeCount; i++) {
      final x = i * spacing + (spacing - sq) / 2;
      canvas.drawRect(Rect.fromLTWH(x, y, sq, sq), paint);
    }
  }

  void _paintHatch(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(rect);
    const step = 6.0;
    for (var x = rect.left - rect.height; x < rect.right; x += step) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) =>
      old.result != result ||
      old.focusMeters != focusMeters ||
      old.bandColor != bandColor ||
      old.dofColor != dofColor;
}

class _MarkerLabels extends StatelessWidget {
  const _MarkerLabels({
    required this.result,
    required this.focusMeters,
    required this.minDist,
    required this.maxDist,
    required this.width,
  });

  final DofResult result;
  final double focusMeters;
  final double minDist;
  final double maxDist;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final near = distToX(result.nearMeters, width, minD: minDist, maxD: maxDist);
    final focusX = distToX(focusMeters, width, minD: minDist, maxD: maxDist);
    final farRaw = result.farMeters ?? double.infinity;
    final far = distToX(farRaw, width, minD: minDist, maxD: maxDist);

    return Stack(
      children: [
        _label(cs, near, FilmStripDofView._fmt(result.nearMeters) + 'm', '近景深',
            highlight: false),
        _label(cs, focusX, FilmStripDofView._fmt(focusMeters) + (focusMeters.isFinite ? 'm' : ''),
            '对焦点', highlight: true),
        _label(cs, far, (result.farMeters == null ? '∞' : FilmStripDofView._fmt(result.farMeters!) + 'm'),
            '远景深', highlight: false),
      ],
    );
  }

  Widget _label(ColorScheme cs, double x, String value, String tag,
      {required bool highlight}) {
    final color = highlight ? AppColors.spotHighlight : cs.onSurface;
    return Positioned(
      left: (x - 28).clamp(0, width - 56),
      bottom: 8,
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            tag,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测确认 pass**

Run: `flutter test test/pages/calc/widgets/film_strip_dof_view_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 5: Lint + commit**

```bash
flutter analyze lib/pages/calc/widgets/film_strip_dof_view.dart test/pages/calc/widgets/film_strip_dof_view_test.dart
git add lib/pages/calc/widgets/film_strip_dof_view.dart test/pages/calc/widgets/film_strip_dof_view_test.dart
git commit -m "feat(calc): add FilmStripDofView with sprocket-holes & DoF band"
```

---

## Task 6: DofParamRow

**Files:**
- Create: `lib/pages/calc/widgets/dof_param_row.dart`
- Test: `test/pages/calc/widgets/dof_param_row_test.dart`

- [ ] **Step 1: 写失败测试**

`test/pages/calc/widgets/dof_param_row_test.dart`：

```dart
import 'package:film_go/pages/calc/widgets/dof_param_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DofParamRow', () {
    testWidgets('渲染 label + value + 刻度，无 = H chip', (t) async {
      await t.pumpWidget(_wrap(DofParamRow(
        label: '焦距',
        displayValue: '50 mm',
        tickLabels: const ['48', '49', '50', '51', '52'],
        activeIndex: 2,
        onIndexChanged: (_) {},
      )));
      expect(find.text('焦距'), findsOneWidget);
      expect(find.text('50 mm'), findsOneWidget);
      expect(find.text('= H'), findsNothing);
    });

    testWidgets('提供 onSnapToHyperfocal 时显示 = H chip 且可点击', (t) async {
      var snapped = false;
      await t.pumpWidget(_wrap(DofParamRow(
        label: '对焦距离',
        displayValue: '5 m',
        tickLabels: const ['3', '5', '7'],
        activeIndex: 1,
        onIndexChanged: (_) {},
        onSnapToHyperfocal: () => snapped = true,
      )));
      expect(find.text('= H'), findsOneWidget);
      await t.tap(find.text('= H'));
      expect(snapped, isTrue);
    });
  });
}
```

- [ ] **Step 2: 跑测确认 fail**

Run: `flutter test test/pages/calc/widgets/dof_param_row_test.dart`
Expected: FAIL

- [ ] **Step 3: 实装**

`lib/pages/calc/widgets/dof_param_row.dart`：

```dart
import 'package:film_go/pages/calc/widgets/horizontal_scale.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 一行：label + value + 横向刻度。对焦距离行额外渲染 `= H` chip。
class DofParamRow extends StatelessWidget {
  const DofParamRow({
    super.key,
    required this.label,
    required this.displayValue,
    required this.tickLabels,
    required this.activeIndex,
    required this.onIndexChanged,
    this.onSnapToHyperfocal,
  });

  final String label;
  final String displayValue;
  final List<String> tickLabels;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback? onSnapToHyperfocal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.spotHighlight,
                  ),
                ),
                if (onSnapToHyperfocal != null) ...[
                  const SizedBox(width: 8),
                  _SnapChip(onTap: onSnapToHyperfocal!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          HorizontalScale(
            labels: tickLabels,
            activeIndex: activeIndex,
            onIndexChanged: onIndexChanged,
          ),
        ],
      ),
    );
  }
}

class _SnapChip extends StatelessWidget {
  const _SnapChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.spotHighlight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '= H',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.spotHighlight,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测确认 pass**

Run: `flutter test test/pages/calc/widgets/dof_param_row_test.dart`
Expected: PASS, 2 tests

- [ ] **Step 5: Lint + commit**

```bash
flutter analyze lib/pages/calc/widgets/dof_param_row.dart test/pages/calc/widgets/dof_param_row_test.dart
git add lib/pages/calc/widgets/dof_param_row.dart test/pages/calc/widgets/dof_param_row_test.dart
git commit -m "feat(calc): add DofParamRow with optional snap-to-H chip"
```

---

## Task 7: CalcPage 装配

**Files:**
- Modify: `lib/pages/calc/calc_page.dart`
- Test: `test/pages/calc/calc_page_test.dart`

把空占位页换成 5 段装配。

- [ ] **Step 1: 写失败测试**

`test/pages/calc/calc_page_test.dart`：

```dart
import 'package:film_go/pages/calc/calc_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: child),
    );

void main() {
  group('CalcPage', () {
    testWidgets('渲染 5 段：可视化 + 4 行参数 + 弥散圆只读', (t) async {
      await t.pumpWidget(_wrap(const CalcPage()));
      await t.pumpAndSettle();
      expect(find.text('对焦距离'), findsOneWidget);
      expect(find.text('焦距'), findsOneWidget);
      expect(find.text('光圈'), findsOneWidget);
      expect(find.text('画幅'), findsOneWidget);
      expect(find.text('弥散圆 c'), findsOneWidget);
      // 摘要行（H = ）
      expect(find.textContaining('H ='), findsOneWidget);
    });

    testWidgets('点 = H chip → 对焦距离值更新成 10m 显示', (t) async {
      await t.pumpWidget(_wrap(const CalcPage()));
      await t.pumpAndSettle();
      // 默认 H≈10.47 → snapToHyperfocal 应跳到 10m 档
      await t.tap(find.text('= H'));
      await t.pumpAndSettle();
      // 对焦距离行的 value 文本应包含 "10"
      expect(find.text('10 m'), findsOneWidget);
    });

    testWidgets('切画幅 chip → 弥散圆显示更新', (t) async {
      await t.pumpWidget(_wrap(const CalcPage()));
      await t.pumpAndSettle();
      expect(find.text('0.030 mm'), findsOneWidget);
      await t.tap(find.text('6×6'));
      await t.pumpAndSettle();
      expect(find.text('0.060 mm'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 跑测确认 fail**

Run: `flutter test test/pages/calc/calc_page_test.dart`
Expected: FAIL（占位页找不到这些文本）

- [ ] **Step 3: 实装**

`lib/pages/calc/calc_page.dart` 完全重写：

```dart
import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/pages/calc/controller/dof_controller.dart';
import 'package:film_go/pages/calc/controller/dof_state.dart';
import 'package:film_go/pages/calc/widgets/dof_param_row.dart';
import 'package:film_go/pages/calc/widgets/film_strip_dof_view.dart';
import 'package:film_go/pages/calc/widgets/format_chip_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalcPage extends ConsumerWidget {
  const CalcPage({super.key});

  static String _fmtFocus(double m) {
    if (!m.isFinite) return '∞';
    return m < 10
        ? '${m.toStringAsFixed(1)} m'
        : '${m.round()} m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(dofControllerProvider);
    final s = c.state;
    return Scaffold(
      appBar: AppBar(title: const Text('景深 · 超焦距')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilmStripDofView(
                result: s.result,
                focusMeters: s.focusMeters,
              ),
            ),
            const Divider(height: 1),
            DofParamRow(
              label: '对焦距离',
              displayValue: _fmtFocus(s.focusMeters),
              tickLabels: [
                for (final v in DofState.focusSteps)
                  if (!v.isFinite) '∞'
                  else if (v == v.truncateToDouble()) v.toInt().toString()
                  else v.toStringAsFixed(1),
              ],
              activeIndex: s.focusDistIndex,
              onIndexChanged: c.setFocusDistIndex,
              onSnapToHyperfocal: c.snapToHyperfocal,
            ),
            const Divider(height: 1),
            DofParamRow(
              label: '焦距',
              displayValue: '${s.focalLengthMm} mm',
              tickLabels: [
                for (var mm = 8; mm <= 500; mm++) mm.toString(),
              ],
              activeIndex: s.focalLengthMm - 8,
              onIndexChanged: (i) => c.setFocalLength(i + 8),
            ),
            const Divider(height: 1),
            DofParamRow(
              label: '光圈',
              displayValue: s.aperture.display,
              tickLabels: [
                for (final a in Aperture.fullStops) a.display.replaceFirst('f/', ''),
              ],
              activeIndex: s.apertureIndex,
              onIndexChanged: c.setApertureIndex,
            ),
            const Divider(height: 1),
            _ParamHeader(label: '画幅', value: s.format.label),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: FormatChipRow(
                active: s.format,
                onChanged: c.setFormat,
              ),
            ),
            const Divider(height: 1),
            _CocReadonlyRow(cocMm: s.cocMm),
          ],
        ),
      ),
    );
  }
}

class _ParamHeader extends StatelessWidget {
  const _ParamHeader({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CocReadonlyRow extends StatelessWidget {
  const _CocReadonlyRow({required this.cocMm});
  final double cocMm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('自定义弥散圆 - 即将上线')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text('弥散圆 c',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),),
            const Spacer(),
            Text(
              '${cocMm.toStringAsFixed(3)} mm',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测确认 pass**

Run: `flutter test test/pages/calc/calc_page_test.dart`
Expected: PASS, 3 tests

- [ ] **Step 5: 跑全量测 + lint**

```bash
flutter test
flutter analyze
```

Expected: 全绿，无新增 warning

- [ ] **Step 6: Commit**

```bash
git add lib/pages/calc/calc_page.dart test/pages/calc/calc_page_test.dart
git commit -m "feat(calc): wire CalcPage to DofController with film-strip visualizer"
```

---

## Task 8: 真机/模拟器手测

不写测试，只做人肉验证。

- [ ] **Step 1: 跑全量回归测**

```bash
flutter test
```

Expected: 全绿

- [ ] **Step 2: 真机跑一遍**

```bash
./scripts/build_android.sh --run
```

跑通后在 Calc Tab 操作：
- 对焦距离左右滑动 → 上方近/远刻度跟着移动
- 焦距 50 → 200 → 上方 DoF 带变窄
- 光圈 f/8 → f/2.8 → 上方 DoF 带变窄
- 画幅 135 → 6×6 → 弥散圆显示 0.060，DoF 带变窄
- 点 `= H` → 对焦距离值跳到 H 最近档
- 把对焦距离拨到 ∞ → 远景显示 ∞、摘要 `总景深 ≈ ∞`

- [ ] **Step 3: 数值与 dofmaster.com 对照（可选）**

抽 3 组对照：
- 135 / 50mm / f/8 / 5m：H ≈ 10.4m，near ≈ 3.4m，far ≈ 9.7m
- 135 / 28mm / f/4 / 3m：H ≈ 6.5m，near ≈ 2.0m，far ≈ 5.6m
- 6×7 / 90mm / f/11 / 5m：H ≈ 11.1m，near ≈ 3.4m，far ≈ 9.0m

数值偏差在 5% 内可接受。

- [ ] **Step 4: 截图存档（可选）**

把 Calc 页 light/dark 截图各一张存到 `docs/superpowers/screenshots/2026-05-25-calc-*.png`，便于后续 PR review。

---

## Self-Review 结果

**Spec 覆盖**：
- ✅ §3.1 复用 DepthOfField — Task 2 `DofState.result` 直接调
- ✅ §3.2 FilmFormat 4 档 + cocMm — Task 1
- ✅ §3.3 16 档 focusSteps / 焦距 1mm / Aperture.fullStops — Task 2 state + Task 7 装配
- ✅ §3.4 默认值 5m / 50mm / f/8 / 135 — Task 2 `DofState.initial`
- ✅ §4.1 FilmStripDofView 齿孔/DoF 带/三标记/∞ 区/摘要 — Task 5
- ✅ §4.2 HorizontalScale + PageView + 中心三角 — Task 3
- ✅ §4.3 DofParamRow + `= H` chip — Task 6
- ✅ §4.4 FormatChipRow — Task 4
- ✅ §4.5 弥散圆只读 + SnackBar 占位 — Task 7 `_CocReadonlyRow`
- ✅ §5 DofController + Riverpod provider + snap — Task 2
- ✅ §6 字符串与数值格式 — Task 5 `_fmt` + Task 7 `_fmtFocus`
- ✅ §7.1/7.2 测试覆盖 — Task 1~7 每个都有
- ⚠️ §7.3 Golden 测延后到 M5（spec 已声明本期不强求）

**Placeholder 扫描**：无 TBD/TODO/「类似 Task N」/「合适的错误处理」。每个 step 都附完整代码或具体命令。

**类型一致性**：
- `DofState.focusSteps` 在 Task 2 定义、Task 7 复用，名字一致
- `DofController.setFocalLength(int mm)` / `setApertureIndex(int i)` / `setFocusDistIndex(int i)` / `setFormat(FilmFormat)` / `snapToHyperfocal()` 在 Task 2 定义、Task 7 调用，签名匹配
- `HorizontalScale` 必填参数 `labels` / `activeIndex` / `onIndexChanged` 在 Task 3 定义、Task 6 + Task 7 复用一致
- `DofParamRow.onSnapToHyperfocal` 类型 `VoidCallback?`，Task 7 传 `c.snapToHyperfocal` 兼容
- `FilmStripDofView(result, focusMeters)` 在 Task 5 定义、Task 7 传 `s.result` + `s.focusMeters`

无不一致。

---

*— Plan ends —*
