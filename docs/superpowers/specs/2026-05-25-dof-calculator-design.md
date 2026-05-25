# 景深 / 超焦距计算器 — 设计

日期：2026-05-25
范围：Calc Tab 第一个子页 — 景深 + 超焦距计算器
作者：兆兆 + Claude

---

## 1. 目标与范围

把当前空占位的 `lib/pages/calc/calc_page.dart` 替换成一个可用的「景深 / 超焦距」计算器，作为 Calc Tab 的首个子功能。

**包含**

- 4 个输入：对焦距离、焦距、光圈、画幅
- 实时计算并显示：近景深、远景深（远=∞ 时显示 ∞）、超焦距 H
- 顶部「胶片卷轴」可视化：近/对焦/远三个标记 + DoF 高亮带
- 「= H」快捷 chip：一键把对焦距离拉到当前超焦距

**不做**

- Calc Tab 首页改造（滤镜 / 互易律 / Sunny 16 子功能保持后续里程碑，本期 Calc Tab 直接就是 DoF 页）
- 与 Meter 页的「右上角浮窗显示当前对焦距离 DoF」联动（M1 spec 提过，本期不做）
- 数码画幅（1 英寸 / M43 / APS-C / 全画幅），坚持胶卷画幅优先
- 自定义弥散圆 c 输入（占位 readOnly，UI 留入口，本期不做交互）
- 距离单位切换（米/英尺），本期只米

---

## 2. 信息架构

单页竖向滚动（不分 Tab）：

```
┌────────────────────────────────────────┐
│  [AppBar] 景深 · 超焦距                │
├────────────────────────────────────────┤
│  ░░░ FilmStripDofView (height 160) ░░░ │ ← 胶片卷轴可视化
│   齿孔上 · DoF 高亮带 · 三标记 · 齿孔下│
│   H = 18.3m   |  总景深 ≈ 12.1m         │
├────────────────────────────────────────┤
│  对焦距离                    24.0 m  [=H]│ ← 行 1
│   …  20  21  22  23 [24] 25  26  …     │
├────────────────────────────────────────┤
│  焦距                        51 mm     │ ← 行 2
│   …  48  49  50 [51] 52  53  54  …     │
├────────────────────────────────────────┤
│  光圈                         f/8.0    │ ← 行 3
│   …  4.0  5.6 [8.0] 11  16  …          │
├────────────────────────────────────────┤
│  画幅                          135     │ ← 行 4
│   [ 135 ] [ 6×6 ] [ 6×7 ] [ 4×5 ]      │
├────────────────────────────────────────┤
│  弥散圆 c               0.030 mm      │ ← 只读
└────────────────────────────────────────┘
```

每行高 76dp（可视化 160dp，c 行 48dp）。整页在小屏上无需滚动；超长屏（小屏 + 系统字号放大）走 `SingleChildScrollView`。

---

## 3. 计算模型

### 3.1 复用 `lib/domain/dof/depth_of_field.dart`

`DepthOfField.compute` 已实现：

```
H  = f²/(N·c) + f
Dn = s·(H−f) / (H + s − 2f)
Df = s·(H−f) / (H − s)       // s ≥ H 时 null
```

`DofResult { nearMeters, farMeters (nullable=∞), hyperfocalMeters }` 直接复用。

### 3.2 新增 `lib/domain/dof/film_format.dart`

```dart
enum FilmFormat {
  f135(label: '135',  cocMm: 0.030),
  f6x6(label: '6×6',  cocMm: 0.060),
  f6x7(label: '6×7',  cocMm: 0.066),
  f4x5(label: '4×5',  cocMm: 0.150);

  final String label;
  final double cocMm;
  const FilmFormat({required this.label, required this.cocMm});
}
```

弥散圆值取自常用工程经验：35mm 民用 0.030mm；6×6 / 6×7 按对角线比例近似；4×5 取大画幅常用 0.150mm（spec 设计稿附录 A 未明确，按行业惯例固定）。

### 3.3 输入定义域

| 参数 | 定义域 | 步进 |
|---|---|---|
| 对焦距离 | 16 档：`0.3, 0.5, 0.7, 1, 1.5, 2, 3, 5, 7, 10, 15, 20, 30, 50, 100, ∞` | 镜头标尺值 |
| 焦距 | 8…500 mm | 1 mm |
| 光圈 | `Aperture.fullStops` 13 档 | 整档 |
| 画幅 | `FilmFormat.values` 4 档 | 单选 |

对焦距离 = ∞ 时：result.nearMeters = H，result.farMeters = null。（实现上 ∞ 单独分支，不调用 `compute(focusDistanceMeters: ∞)`。）

### 3.4 默认值

- 焦距 50mm（135 标头）
- 光圈 f/8
- 画幅 135
- 对焦距离 5m（取 16 档常用第 7 档；街拍/纪实典型距离）

---

## 4. UI 与组件

### 4.1 顶部 `FilmStripDofView`（widgets/film_strip_dof_view.dart）

```dart
class FilmStripDofView extends StatelessWidget {
  final DofResult result;       // null=未计算/异常时另算 placeholder
  final double focusMeters;     // 含 ∞=double.infinity
  final double minDist;         // 0.3
  final double maxDist;         // 1000
}
```

布局（高 160dp）：

```
┌─ 上齿孔行 height 16 ─────────────┐
│ ▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢ │
├─────────────────────────────────┤
│           DoF Band               │ height 80
│   ▪      ▒▒▒▒▒▒▒▒▒▒▒▒▒▒    ∞   │ 高亮带 + 3 标记
│  near    focus              far │
├─────────────────────────────────┤
│ ▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢▢ │ 下齿孔行 height 16
├─────────────────────────────────┤
│ H = 18.3m  |  总景深 ≈ 12.1m    │ height 32
└─────────────────────────────────┘
```

**横轴映射函数（pure）**

```dart
double distToX(double meters, double widthPx, {required double minD, required double maxD}) {
  if (meters == double.infinity) return widthPx - widthPx * 0.04; // ∞ 落在右端 4% 处
  final clamped = meters.clamp(minD, maxD);
  final t = (log(clamped) - log(minD)) / (log(maxD) - log(minD));
  return t * widthPx * 0.92; // 留右侧 8% 给 ∞ 区
}
```

**画法（一个 CustomPainter 完成）**

- 齿孔：上下各 24 个 8×8 描边正方形，间距按宽度等分；stroke `cs.outlineVariant`
- 中间 DoF 带区域底色：`cs.surfaceContainerHighest`（暖灰），保持页面调性，不做黑白反色
- DoF 高亮带：从 distToX(near) 到 distToX(far ?? ∞)，rect 填 `AppColors.spotHighlight.withOpacity(0.35)`
- 三个标记：
  - near 标记：竖线 + 下方文字「11.9m / 近景深」
  - focus 标记：竖线（粗，`AppColors.spotHighlight`）+ 上方文字「24m / 对焦点」
  - far 标记：竖线 + 下方文字「∞ / 远景深」或具体米数
- ∞ 区（右侧 8%）：浅灰斜纹背景，提示「>1km 区域」

**文字字体**：JetBrains Mono，距离值 18sp w800，标签 11sp w400。

### 4.2 通用 `HorizontalScale`（widgets/horizontal_scale.dart）

```dart
class HorizontalScale extends StatefulWidget {
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final double itemExtent;     // 默认 56
  final double height;         // 默认 44
}
```

实现：

- `PageView.builder(scrollDirection: Axis.horizontal, controller: PageController(viewportFraction: itemExtent / context.width), pageSnapping: true)`
- 子项：宽 `itemExtent`，居中文字
  - active：`cs.onSurface`，16sp w800，JetBrains Mono
  - 旁侧：`cs.onSurfaceVariant`，13sp w400
- 中心指示：`Stack` 顶层放一个 16×6 的下三角 `▼`，颜色 `AppColors.spotHighlight`
- `onPageChanged`：触发 `onIndexChanged`
- `didUpdateWidget`：若 `widget.activeIndex != _controller.page.round()` → `animateToPage(activeIndex, 200ms, easeOut)`
- 同步标志 `_syncing` 防双向回调死循环（沿用 DualScale 的写法）

> 备注：`PageView` 的 `viewportFraction` 要求小于 1。我们传入显式 `itemExtent` 56dp，运行时按 `MediaQuery.size.width` 计算 viewportFraction。`LayoutBuilder` 包一层拿到准确宽度。

### 4.3 `DofParamRow`（widgets/dof_param_row.dart）

每行 = 标签 + 当前值 + HorizontalScale 三件套。`= H` chip 仅在 `label == '对焦距离'` 时显示。

```dart
class DofParamRow extends StatelessWidget {
  final String label;
  final String displayValue;
  final List<String> tickLabels;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback? onSnapToHyperfocal; // null 时不渲染 chip
}
```

布局：
- 上行：label 左、displayValue 右、（可选）`= H` chip 在 value 右侧
- 下行：HorizontalScale，全宽

### 4.4 `FormatChipRow`（widgets/format_chip_row.dart）

4 个 `ChoiceChip` 平铺，宽度等分。选中态：填 `AppColors.spotHighlight`、文字 `charcoalBlack`、bold；未选中：描边 `cs.outlineVariant`、文字 `cs.onSurfaceVariant`。

### 4.5 弥散圆只读行

样式同 `DofParamRow` 但下半部分用一行小字 `0.030 mm`（不可交互）。点击整行触发未实现的 SnackBar「自定义弥散圆 - 即将上线」（占位口子，便于以后接入）。

---

## 5. 状态管理

### 5.1 State（`lib/pages/calc/controller/dof_state.dart`）

```dart
@immutable
class DofState {
  final int focusDistIndex;   // 0..15
  final int focalLengthMm;    // 8..500
  final int apertureIndex;    // 0..(Aperture.fullStops.length-1)
  final FilmFormat format;

  const DofState({...});
  DofState copyWith({...});

  // 派生
  static const List<double> focusSteps = [
    0.3, 0.5, 0.7, 1, 1.5, 2, 3, 5, 7, 10, 15, 20, 30, 50, 100,
    double.infinity,
  ];

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
      // 对焦于 ∞：near = H，far = ∞
      return DofResult(nearMeters: h, farMeters: null, hyperfocalMeters: h);
    }
    return DepthOfField.compute(
      focalLengthMm: focalLengthMm.toDouble(),
      aperture: aperture,
      circleOfConfusionMm: cocMm,
      focusDistanceMeters: focusMeters,
    );
  }
}
```

默认：`DofState.initial = DofState(focusDistIndex: 7 /*5m*/, focalLengthMm: 50, apertureIndex: 6 /*f/8*/, format: FilmFormat.f135)`。

### 5.2 Controller（`controller/dof_controller.dart`）

```dart
class DofController extends Notifier<DofState> {
  @override DofState build() => DofState.initial;

  void setFocusDistIndex(int i) => state = state.copyWith(focusDistIndex: i);
  void setFocalLength(int mm) => state = state.copyWith(focalLengthMm: mm);
  void setApertureIndex(int i) => state = state.copyWith(apertureIndex: i);
  void setFormat(FilmFormat f) => state = state.copyWith(format: f);

  /// = H：把 focusDistIndex 跳到「最接近 H 的档」或直接选 ∞（如果 H > 100m）
  void snapToHyperfocal() {
    final h = state.result.hyperfocalMeters;
    if (h > 100) {
      state = state.copyWith(focusDistIndex: DofState.focusSteps.length - 1); // ∞
      return;
    }
    int best = 0;
    double bestDiff = double.infinity;
    for (var i = 0; i < DofState.focusSteps.length - 1; i++) {
      final d = (DofState.focusSteps[i] - h).abs();
      if (d < bestDiff) { bestDiff = d; best = i; }
    }
    state = state.copyWith(focusDistIndex: best);
  }
}

final dofControllerProvider =
    NotifierProvider<DofController, DofState>(DofController.new);
```

### 5.3 持久化

本期不持久化（与 Meter 的 quick state 同等处理）。重启 App 回到默认。后续如需要可加 SharedPreferences 一处即可。

---

## 6. 文本与字符串

固定 zh-CN（与项目当前一致）：

| Key | Text |
|---|---|
| AppBar 标题 | `景深 · 超焦距` |
| 行 1 | `对焦距离` |
| 行 2 | `焦距` |
| 行 3 | `光圈` |
| 行 4 | `画幅` |
| 只读行 | `弥散圆 c` |
| Chip | `= H` |
| 摘要 | `H = {h}m  ·  总景深 ≈ {dofRange}` |
| 远景 ∞ | `∞` |
| 标记 | `近景深` / `对焦点` / `远景深` |

数值格式化：
- `{h}` = `H.toStringAsFixed(1)`（保留 1 位小数）
- 距离标记（near/focus/far）：`< 10m` 保留 1 位小数；`>= 10m` 取整
- `{dofRange}`：far 为有限 → `(far - near).toStringAsFixed(1) + 'm'`；far 为 ∞ → `∞`

---

## 7. 测试策略

### 7.1 单测（pure）

`test/domain/dof/film_format_test.dart`
- 4 档 cocMm 值断言
- label 字符串断言

`test/pages/calc/controller/dof_controller_test.dart`
- 默认值断言（focusMeters=5, aperture=f/8, format=135, focalLength=50）
- setFocalLength/setApertureIndex/setFormat 联动 result
- 对焦 ∞ 时 result.farMeters == null && result.nearMeters == H
- `snapToHyperfocal()`：H < 100 时选最接近档；H > 100 时选 ∞ 档
- focusSteps 长度 16，末位 == double.infinity

### 7.2 Widget 测

`test/pages/calc/widgets/horizontal_scale_test.dart`
- pump 后 controller.page == activeIndex
- 模拟 fling → onIndexChanged 被调用
- 父层换 activeIndex → animateToPage 触发（验证 controller.page）

`test/pages/calc/widgets/film_strip_dof_view_test.dart`
- result.farMeters == null → ∞ 区 marker 渲染
- distToX 映射断言：focus=10m, width=400 → 期望 x 在 200±10 范围
- 给定 result 触发 paint 不抛异常（boundary smoke）

`test/pages/calc/widgets/format_chip_row_test.dart`
- 4 个 chip 渲染
- 点击非默认 chip → onChanged(format) 调用

`test/pages/calc/calc_page_test.dart`
- pump CalcPage → 5 段（visualizer + 4 row + c 行）都存在
- 操作焦距 PageView → DofState 联动、可视化标记位置更新（用 finder 检查文字 `H = ...`）

### 7.3 Golden 测

后续 M5 上线前补一张 calc_page.dark.png + light.png。本期不强求。

---

## 8. 文件改动清单

**新增**
- `lib/domain/dof/film_format.dart`
- `lib/pages/calc/controller/dof_state.dart`
- `lib/pages/calc/controller/dof_controller.dart`
- `lib/pages/calc/widgets/film_strip_dof_view.dart`
- `lib/pages/calc/widgets/horizontal_scale.dart`
- `lib/pages/calc/widgets/dof_param_row.dart`
- `lib/pages/calc/widgets/format_chip_row.dart`
- `test/domain/dof/film_format_test.dart`
- `test/pages/calc/controller/dof_controller_test.dart`
- `test/pages/calc/widgets/horizontal_scale_test.dart`
- `test/pages/calc/widgets/film_strip_dof_view_test.dart`
- `test/pages/calc/widgets/format_chip_row_test.dart`
- `test/pages/calc/calc_page_test.dart`

**修改**
- `lib/pages/calc/calc_page.dart`（占位 → 真实实现，约 80 行）

**不动**
- `lib/domain/dof/depth_of_field.dart`（公式复用）
- 其他 page / theme / service 模块

---

## 9. 风险与回滚

| 风险 | 缓解 |
|---|---|
| `PageView + viewportFraction` 在窄屏（< 360dp）上单个 itemExtent 56 过宽，旁侧只能显示 2~3 个 | `LayoutBuilder` 拿宽度后计算 viewportFraction，最低 0.15 保 5 个；窄屏自然变挤可接受 |
| `FilmStripDofView` 用 log scale 时 minDist=0.3 / maxDist=1000 在 small focus（1m 内）下 near/far 几乎重叠，可视化不明显 | 文字标记总是显示，画幅本身就反映「景深极浅」事实；不为可视化牺牲数学诚实 |
| ∞ 焦距走单独分支，`compute()` 不能传 ∞ → 视图层判断 `focusMeters.isFinite` | State 派生层兜底，单测覆盖 |
| 16 档对焦距离对超广角微距用户偏少 | 16 档覆盖镜头标尺主刻度，本期够用；后续接入自定义距离再扩 |
| `snapToHyperfocal` 把焦距吸到最近档可能与 H 偏离 10~20% | 行为符合「按镜头标尺对焦」物理直觉；UI 可视化仍按真实 H 画带 |

回滚：本次改动只新增文件 + 重写一个 80 行的 page。`git revert` 这一次 commit 即完全回到占位页。

---

## 10. 实现顺序（给后续 writing-plans 的提示）

1. domain：`FilmFormat` + test
2. controller：`DofState` + `DofController` + test
3. widget 原子：`HorizontalScale` + test
4. widget 原子：`FormatChipRow` + test
5. widget 复合：`FilmStripDofView`（CustomPainter）+ test
6. widget 复合：`DofParamRow`（含 `= H` chip 分支）
7. page 装配：`CalcPage` 重写 + page test
8. 手测：真机/模拟器跑一圈，验证滚动手感、可视化精度、各画幅 H 数值与 dofmaster.com 对照

---

*— Spec ends —*
