# 视觉系统暖化 + 测光交互修复 — 设计

日期：2026-05-25
范围：色板/主题、快速测光双滚轮 + 整档快门、专业测光拍照修复

---

## 1. 目标

1. 打破当前严格黑白的二元色板，让 UI 保留"暗房/胶片"氛围的同时具备真实的视觉层次。
2. 把快速测光的快门刻度收敛到摄影惯例的整档值（30s..1/8000），并把"曝光对"从纯展示升级为**双滚轮交互**：两列可独立滚动，同 EV 自动镜像滚到对应档位。
3. 修复专业测光页拍照功能失效（取景流与拍照互斥、相册保存为空实现两个 bug）。

非目标：不改测光算法（EV 计算、灰度提取、相机帧管线）、不动 Pro 顶部状态栏与 ScaleStrip 布局、不引入新依赖（`image_gallery_saver` 已在 `pubspec.yaml`）。

---

## 2. 配色系统

### 2.1 新 token（`lib/theme/app_colors.dart`）

替换当前的 `black`/`white`/灰阶/`darkroomRed`，改为暖灰胶片调：

| token | 值 | 用途 |
|---|---|---|
| `paperWhite` | `#F5F1EA` | Light 模式底色 |
| `charcoalBlack` | `#1B1816` | Dark 模式底色 / Light 模式前景 |
| `surfaceHighLight` | `#ECE6DC` | Light 模式 surfaceContainerHighest |
| `surfaceLowLight` | `#DDD6C8` | Light 模式 surfaceContainerHigh |
| `surfaceHighDark` | `#2A2522` | Dark 模式 surfaceContainerHighest |
| `surfaceLowDark` | `#221E1B` | Dark 模式 surfaceContainerHigh |
| `divider` | `#BDB4A4` | 边线/outlineVariant |
| `muted` | `#6F665C` | 次级文字/onSurfaceVariant |
| `darkroomRed` | `#B33A2A` | 唯一强调色（保留语义） |
| `spotHighlight` | `#E8C77A` | Pro spot 框 / 高亮（替换原 amber，更贴胶片调） |

旧的 `black` `white` `gray100..900` 全部删除——所有调用方都改走 `ColorScheme`，避免再次硬编码。

### 2.2 主题装配（`lib/theme/app_theme.dart`）

```
ColorScheme(
  brightness,
  primary:           fg,
  onPrimary:         bg,
  secondary:         muted,
  onSecondary:       bg,
  surface:           bg,
  onSurface:         fg,
  surfaceContainerHighest: surfaceHigh,
  surfaceContainerHigh:    surfaceLow,
  onSurfaceVariant:  muted,
  outline:           divider,
  outlineVariant:    divider,
  error:             darkroomRed,
  onError:           paperWhite,
)
```

dark：`bg = charcoalBlack`、`fg = paperWhite`、`surfaceHigh = surfaceHighDark` / `surfaceLow = surfaceLowDark`。
light：`bg = paperWhite`、`fg = charcoalBlack`、`surfaceHigh = surfaceHighLight` / `surfaceLow = surfaceLowLight`。

### 2.3 调用方迁移

| 文件 | 旧 | 新 |
|---|---|---|
| `pages/meter/meter_page.dart:110` | `Colors.black` | 保留：Pro 全屏取景需要纯黑底，改为 `AppColors.charcoalBlack` |
| `pages/meter/pro/pro_meter_view.dart:149` | `Colors.black` | `AppColors.charcoalBlack` |
| `pages/meter/pro/pro_meter_view.dart:151` | `Colors.white24` | `cs.onSurface.withOpacity(0.24)` |
| `pages/meter/pro/widgets/pro_top_status_bar.dart:21` | `Colors.white` | `cs.onSurface`（暗背景上仍是 paperWhite） |
| `pages/meter/pro/widgets/shutter_button.dart` | 硬编码 white/black | `cs.onSurface` / `cs.surface` |
| `pages/meter/pro/widgets/pro_readout.dart:15` | `Colors.white` | `cs.onSurface` |
| `pages/meter/pro/widgets/meter_mode_cycle_button.dart` | `Colors.white.withOpacity` | `cs.onSurface.withOpacity` |
| `pages/meter/pro/widgets/scale_strip.dart:61,82` | `Colors.white60/70`, `Colors.amber` | `cs.onSurface.withOpacity(...)`, `AppColors.spotHighlight` |
| `pages/meter/pro/widgets/spot_overlay.dart:39` | `Colors.amber` | `AppColors.spotHighlight` |

Pro 是全屏黑底相机预览，所以 `ColorScheme.dark` 的 fg=paperWhite 直接在该场景生效，过渡自然，不需要单独维护一套 Pro 主题。

---

## 3. 快速测光：整档快门 + 双滚轮

### 3.1 标准快门档位（`lib/domain/shared/shutter_speed.dart`）

新增静态常量：

```dart
static const List<ShutterSpeed> fullStops = [
  ShutterSpeed.seconds(30), 15, 8, 4, 2, 1,
  ShutterSpeed.seconds(1/2), 1/4, 1/8, 1/15, 1/30,
  1/60, 1/125, 1/250, 1/500, 1/1000, 1/2000, 1/4000, 1/8000,
];
```

（实现上需要让 const 构造跳过 `seconds<=0` 校验——参考 `Aperture._unchecked` 的写法。）

### 3.2 ExposurePair 生成改造（`lib/domain/metering/ev_calculator.dart`）

`suggestPairs` 当前对每个光圈解析自由快门 `t = N² / 2^EV`，得到非标值（如 1/237.5s）。改造：

```
对每档 Aperture.fullStops：
  理论 t = N² / 2^(EV - log2(ISO/100))
  找 ShutterSpeed.fullStops 中 |log2(t / candidate)| 最小者
  若误差 > 0.5 stop（半档），丢弃该光圈
  否则产出 ExposurePair(aperture=ap, shutter=snapped)
按 EV 中心排序（实际上同 EV 下 aperture 单调递增即可）
```

排序天然由 `fullStops` 顺序保证；中点 `pairs.length ~/ 2` 仍是推荐对。

### 3.3 DualScale 重构为双滚轮

`lib/pages/meter/widgets/dual_scale.dart` 改成 `StatefulWidget`，新 API：

```dart
DualScale({
  required List<ExposurePair> pairs,
  required int activeIndex,           // 父层算好的当前选中 index
  required ValueChanged<int> onIndexChanged,
})
```

内部两个 `FixedExtentScrollController`（shutter / aperture）：
- `itemExtent = 32`，`physics = FixedExtentScrollPhysics`
- 中央高亮带（Container with `surfaceContainerHighest`，圆角 8）固定在中线
- 列表内容是 `pairs` 数组：左列 `pair.shutter.display`，右列 `pair.aperture.display`，两列共享同一个 index 空间
- `onSelectedItemChanged`（任一列）→ 调 `widget.onIndexChanged(i)` 并 `animateToItem` 同步另一列
- 用 `_syncing` 标志避免双向回调死循环（父层 setState 回流时不再触发 onIndexChanged）
- `didUpdateWidget`：若 `widget.activeIndex != _ctrl.selectedItem` 就两列各 `animateToItem(activeIndex)`

### 3.4 状态：`QuickModeState.pairIndex`

`lib/pages/meter/controller/meter_state.dart`：`QuickModeState` 新增 `int? userPairOffset`（相对中点的偏移，单位 = 档位 index）。

视图层换算：
```
center = pairs.length ~/ 2
activeIndex = (center + (userPairOffset ?? 0)).clamp(0, pairs.length - 1)
```

行为：
- 默认 `null`，DualScale 显示中点
- 用户滚动 → `quickSetPairOffset(activeIndex - center)` → 存 `userPairOffset`
- 测光值变化 → `pairs` 列表长度可能变化 → 重新算 `activeIndex`，clamp 后两列 animate 到新位置
- 锁定/解锁不影响 offset；切 ISO/COMP/FILTER 不重置 offset（用户已选定）
- 提供 `quickResetPairOffset()` 给"重置"按钮（暂不暴露 UI，仅 API 留口）

### 3.5 QuickDrum 中 EV100 列的去留

保留——QuickDrum 的 EV100 滚轮仍负责"手动锁定 EV"（练习/对比场景），与 DualScale 的"选择曝光对"是正交职责：
- EV100 列：改变测光读数本身
- DualScale 双滚轮：在同一 EV 下选不同等价曝光对

---

## 4. 专业测光：拍照修复

### 4.1 根因

`lib/pages/meter/meter_page.dart:56-69`：

```dart
capture: () async {
  final controller = _camera.controller;
  final file = await controller.takePicture();  // ❌ 帧流活跃时报 CameraException
  return Uint8List.fromList(await file.readAsBytes());
},
saveToGallery: (bytes, name) async {
  // 空实现（占位注释）
},
```

两个独立 bug：(a) `camera` 插件不允许 `takePicture()` 与 `startImageStream()` 并存；(b) 落盘逻辑没有真正接入 `image_gallery_saver`。

### 4.2 修复

**capture 回调**（`meter_page.dart`）：

```dart
capture: () async {
  final controller = _camera.controller;
  if (controller == null) throw StateError('相机未初始化');
  await _camera.stop();          // 暂停 image stream
  try {
    final file = await controller.takePicture();
    return Uint8List.fromList(await file.readAsBytes());
  } finally {
    await _camera.start();        // 无论成败都恢复取景
  }
},
```

**saveToGallery 回调**：

```dart
saveToGallery: (bytes, name) async {
  await ImageGallerySaver.saveImage(
    bytes,
    name: name,
    quality: 90,
    isReturnImagePathOfIOS: true,
  );
},
```

`ImageGallerySaver` 来自已加入的 `image_gallery_saver: ^2.0.3`。

### 4.3 CameraService 暴露的 start/stop 已经幂等（`_streaming` flag），无需改动；但要在文档里点明：连续两次 `start()` 不会重复挂 listener。

### 4.4 错误处理

- 拍照失败（权限、设备忙）：`ProMeterView._onShutter` 已经在 `finally` 里复位 `_capturing=false`；额外捕获异常并通过 `ScaffoldMessenger.showSnackBar` 弹一条"拍照失败"。
- 取景恢复失败：极小概率，目前忽略——下一帧 `processCameraFrame` 不来时 UI 自动停在最后一次 metered 上。

---

## 5. 测试策略

### 5.1 单测（widget / pure）

- `ev_calculator_test.dart`：新增 case，给定 EV / ISO 后产出的 `pair.shutter.seconds` 必须 ∈ `ShutterSpeed.fullStops`；中心档与理论值差距 ≤ 0.5 stop。
- `shutter_speed_test.dart`：`fullStops` 长度 19、首尾值正确、`display` 字符串符合 `1/125` 与 `30s` 格式。
- `dual_scale_test.dart`：
  - 给 `pairs` 列表，pump 后两列 ListWheel 的 controller `selectedItem` 都等于 `activeIndex`
  - 模拟拖动其中一列触发 `onIndexChanged`
  - `activeIndex` 变化后两列 animateToItem 到同一 index
- `meter_controller_test.dart`：`quickSetPairOffset` / `quickResetPairOffset` 行为；切 ISO 后 offset 仍保留。

### 5.2 主题快照

- `app_theme_test.dart`：light/dark 主题的 `colorScheme.surface` / `onSurface` / `outline` / `error` 等关键 token 与新 `AppColors` 值一致。

### 5.3 集成（手测）

- 真机：Pro 页点拍照按钮 → 帧流暂停 → 拍照成功 → 帧流恢复 → 相册出现带水印的 JPG。
- 快速页：滚动左列快门 → 右列光圈同步滚到匹配档；测光值缓变时两列一起平滑滚动到新中心。

---

## 6. 文件改动清单

新增：无

修改：
- `lib/theme/app_colors.dart` — 重写
- `lib/theme/app_theme.dart` — surface 层级注入
- `lib/domain/shared/shutter_speed.dart` — `fullStops` 常量 + `_unchecked` const 构造
- `lib/domain/metering/ev_calculator.dart` — `suggestPairs` 改为快门吸附整档
- `lib/pages/meter/controller/meter_state.dart` — `QuickModeState.userPairOffset`
- `lib/pages/meter/controller/meter_controller.dart` — `quickSetPairOffset` / `quickResetPairOffset`
- `lib/pages/meter/widgets/dual_scale.dart` — 重写为双滚轮
- `lib/pages/meter/quick/quick_meter_view.dart` — 接 `pairIndex` + 回调，DualScale 宽度可能从 120 放宽到 140 适配双滚轮
- `lib/pages/meter/meter_page.dart` — capture 包 stop/start，saveToGallery 接真插件
- `lib/pages/meter/pro/pro_meter_view.dart` — 配色 token 替换 + 拍照失败 SnackBar
- `lib/pages/meter/pro/widgets/*.dart` — 配色 token 替换

测试：
- `test/domain/shared/shutter_speed_test.dart`（新增 fullStops 断言）
- `test/domain/metering/ev_calculator_test.dart`（更新预期）
- `test/pages/meter/widgets/dual_scale_test.dart`（重写）
- `test/pages/meter/controller/meter_controller_test.dart`（新增 pairOffset case）
- `test/theme/app_theme_test.dart`（新增 token 断言）

---

## 7. 风险与回滚

- 风险：删除 `AppColors.black/white/gray*` 可能让外部硬编码处编译失败。已在 §2.3 列全所有调用方；编译能直接暴露遗漏。
- 风险：`suggestPairs` 阈值 0.5 stop 取得过严会让推荐对数量骤减。备选放宽到 0.75 stop。
- 风险：拍照期间 `stop()` → `start()` 的小段无帧时间内 metered EV 可能短暂消失。可接受（拍照本就该是瞬时动作）。
- 回滚：本次改动按文件维度互相独立，配色 / 双滚轮 / 拍照修复可独立 revert。
