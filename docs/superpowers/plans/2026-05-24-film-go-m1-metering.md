# Film Go M1 — 测光功能 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 Meter Tab 全部测光能力——支持相机取景、Android 光线传感器、手动输入三种 EV 来源；支持点测/中央重点/平均三种测光模式；输出当前 EV 与按 ISO/锁定值算出的整档光圈—快门组合；提供首次校准入口。

**Architecture:** 沿用 M0 分层。Domain 层加 `metering` 子模块（K=12.5 反射光常数公式 + 加权平均 + 校准偏移），纯 Dart、TDD 全覆盖。Adapter 层新增 `CameraService` / `LightSensorService` 包装平台插件，并把帧处理委托给 Domain 层的 `LuminanceExtractor`，保证 isolate 中跑的代码可被单元测试。Presentation 层 `MeterPage` 改造为 ConsumerStatefulWidget，状态由 `MeterController` (Notifier) 持有，按数据来源（camera/sensor/manual）切换源订阅。

**Tech Stack:** Flutter 3.x · Riverpod 2.x · `camera`（取景帧）· `light`（Android ALS）· `permission_handler`（运行时权限）· `shared_preferences`（校准偏移持久化）· isolate via `compute()`。

**约定（与 M0 一致）：**
- 仓根即 `film-go/`，所有命令在仓根执行；`flutter` 命令同样在此执行
- commit 风格：`type: 中文描述`（保持与 M0 首个 commit `chore: initial commit for film-go M0 skeleton` 一致，type ∈ {feat, fix, docs, chore, test, refactor}）
- 每个 task 末尾 commit，仅 add 当 task 涉及文件，不要 `git add .`
- Domain 层 100% TDD：先写测试看到红 → 实现 → 看到绿
- 单文件不超过 300 行，超过则拆分

**范围澄清：本计划仅做 M1 中的"测光"部分。**景深页 / 胶卷库装载 / 互易律联动 / 滤镜补偿联动 不在此计划，留给后续 plan。本计划完成后，MeterPage 的 EV 输出已经可以未来对接互易律/滤镜模块（通过 controller 暴露的 `currentEV` 与 `effectiveEV` 字段）。

---

## 文件结构（M1 测光完成后的样子）

```
film-go/
├─ pubspec.yaml                                # 新增 camera/light/permission_handler/shared_preferences
├─ ios/Runner/Info.plist                       # 增加 NSCameraUsageDescription
├─ android/app/src/main/AndroidManifest.xml    # 增加 CAMERA 权限
├─ lib/
│  ├─ domain/
│  │  ├─ shared/
│  │  │  └─ iso_value.dart                     # ISO 值对象 (常用整档列表 + 半档/三分挡支持)
│  │  └─ metering/
│  │     ├─ ev_calculator.dart                 # (已有) EV ↔ 光圈快门
│  │     ├─ luminance_to_ev.dart               # 亮度 → EV (K=12.5 + 校准偏移)
│  │     ├─ luminance_extractor.dart           # 从 YUV/灰度缓冲区按模式取均值
│  │     ├─ meter_mode.dart                    # spot / center / average
│  │     └─ meter_reading.dart                 # 一次测光快照（值对象）
│  ├─ services/
│  │  ├─ camera_service.dart                   # camera 插件包装：preview + frame stream
│  │  ├─ light_sensor_service.dart             # light 插件包装：lux stream
│  │  └─ calibration_store.dart                # SharedPreferences 持久化校准偏移
│  ├─ pages/meter/
│  │  ├─ meter_page.dart                       # 主页（ConsumerStatefulWidget）
│  │  ├─ controller/
│  │  │  ├─ meter_state.dart                   # 不可变 state
│  │  │  └─ meter_controller.dart              # Notifier
│  │  └─ widgets/
│  │     ├─ meter_dial.dart                    # 圆形指针 + 扇形刻度（CustomPainter）
│  │     ├─ ev_readout.dart                    # 大数字 EV 与 source 标签
│  │     ├─ exposure_pair_list.dart            # 横滑光圈—快门组合
│  │     ├─ iso_selector.dart                  # ISO 滚轮
│  │     ├─ mode_selector.dart                 # 点测/中央重点/平均
│  │     ├─ source_selector.dart               # 相机/传感器/手动
│  │     ├─ manual_ev_dialog.dart              # 手动输入 EV
│  │     ├─ lock_button.dart                   # 锁定 EV
│  │     └─ calibration_dialog.dart            # 首次校准
│  └─ ...
└─ test/
   ├─ domain/
   │  ├─ shared/iso_value_test.dart
   │  └─ metering/
   │     ├─ luminance_to_ev_test.dart
   │     ├─ luminance_extractor_test.dart
   │     ├─ meter_mode_test.dart
   │     └─ meter_reading_test.dart
   ├─ services/
   │  └─ calibration_store_test.dart
   └─ pages/meter/
      ├─ meter_controller_test.dart
      └─ meter_page_smoke_test.dart
```

---

## Task 1: Domain — ISO 值对象

**Files:**
- Create: `lib/domain/shared/iso_value.dart`
- Create: `test/domain/shared/iso_value_test.dart`

**Why now:** EV 公式两端都用到 ISO，把它做成值对象后续 Aperture/Shutter/EV 都可以严格签名，避免 magic int。

- [ ] **Step 1: 写测试**

写入 `test/domain/shared/iso_value_test.dart`：

```dart
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IsoValue', () {
    test('常见整档序列覆盖 ISO 25 到 6400', () {
      final stops = IsoValue.fullStops;
      expect(stops.first.value, 25);
      expect(stops.last.value, 6400);
      // 整档比相邻 ISO 值约 2 倍
      for (var i = 1; i < stops.length; i++) {
        final ratio = stops[i].value / stops[i - 1].value;
        expect(ratio, closeTo(2.0, 1e-9));
      }
    });

    test('display 直接输出整数', () {
      expect(const IsoValue(400).display, 'ISO 400');
      expect(const IsoValue(1600).display, 'ISO 1600');
    });

    test('两个相同 ISO 的对象相等', () {
      expect(const IsoValue(400), const IsoValue(400));
      expect(const IsoValue(400).hashCode, const IsoValue(400).hashCode);
    });

    test('非正 ISO 抛 ArgumentError', () {
      expect(() => IsoValue(0), throwsArgumentError);
      expect(() => IsoValue(-100), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: 跑测试看到红**

Run（在 `film-go/`）：
```bash
flutter test test/domain/shared/iso_value_test.dart
```
Expected: 失败（类不存在）。

- [ ] **Step 3: 写实现**

写入 `lib/domain/shared/iso_value.dart`：

```dart
import 'package:meta/meta.dart';

/// 胶卷或数字传感器的 ISO 感光度。
@immutable
class IsoValue {
  IsoValue(this.value) {
    if (value <= 0) {
      throw ArgumentError.value(value, 'value', '必须为正数');
    }
  }

  const IsoValue._unchecked(this.value);

  final int value;

  String get display => 'ISO $value';

  static const List<IsoValue> fullStops = <IsoValue>[
    IsoValue._unchecked(25),
    IsoValue._unchecked(50),
    IsoValue._unchecked(100),
    IsoValue._unchecked(200),
    IsoValue._unchecked(400),
    IsoValue._unchecked(800),
    IsoValue._unchecked(1600),
    IsoValue._unchecked(3200),
    IsoValue._unchecked(6400),
  ];

  @override
  bool operator ==(Object other) => other is IsoValue && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
```

- [ ] **Step 4: 跑测试看到绿**

```bash
flutter test test/domain/shared/iso_value_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/domain/shared/iso_value.dart test/domain/shared/iso_value_test.dart
git commit -m "feat: 增加 IsoValue 值对象（含整档序列）"
```

---

## Task 2: Domain — 测光模式枚举

**Files:**
- Create: `lib/domain/metering/meter_mode.dart`
- Create: `test/domain/metering/meter_mode_test.dart`

- [ ] **Step 1: 写测试**

写入 `test/domain/metering/meter_mode_test.dart`：

```dart
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeterMode', () {
    test('三种模式定义', () {
      expect(MeterMode.values, hasLength(3));
      expect(MeterMode.values, contains(MeterMode.spot));
      expect(MeterMode.values, contains(MeterMode.centerWeighted));
      expect(MeterMode.values, contains(MeterMode.average));
    });

    test('display 中文标签', () {
      expect(MeterMode.spot.display, '点测');
      expect(MeterMode.centerWeighted.display, '中央重点');
      expect(MeterMode.average.display, '平均');
    });
  });
}
```

- [ ] **Step 2: 看到红**

```bash
flutter test test/domain/metering/meter_mode_test.dart
```

- [ ] **Step 3: 写实现**

写入 `lib/domain/metering/meter_mode.dart`：

```dart
/// 测光模式。
enum MeterMode {
  /// 点测：取手指点选区域 5%。
  spot,

  /// 中央重点：中心 25% 权重 0.75，边缘权重 0.25。
  centerWeighted,

  /// 平均：整帧均值。
  average;

  String get display => switch (this) {
        MeterMode.spot => '点测',
        MeterMode.centerWeighted => '中央重点',
        MeterMode.average => '平均',
      };
}
```

- [ ] **Step 4: 看到绿**

```bash
flutter test test/domain/metering/meter_mode_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/domain/metering/meter_mode.dart test/domain/metering/meter_mode_test.dart
git commit -m "feat: 增加 MeterMode 枚举（点测/中央重点/平均）"
```

---

## Task 3: Domain — 亮度提取器

**Files:**
- Create: `lib/domain/metering/luminance_extractor.dart`
- Create: `test/domain/metering/luminance_extractor_test.dart`

**输入契约：**Camera 插件给 Android 的 YUV420 第 0 plane = Y（灰度），iOS 的 BGRA 需要先转灰度（在相机服务里做）。Domain 这一层只接受"已经是灰度"的 `Uint8List` + width + height + bytesPerRow（stride，可能 ≠ width）。这样 Domain 100% pure Dart 可测。

公式：
- `average`：整帧 Y 的均值
- `centerWeighted`：中心 25% 矩形均值 × 0.75 + 整帧均值 × 0.25
- `spot`：以归一化坐标 (cx, cy) 为中心、边长为短边 5% 的方形均值

返回值 `[0, 255]` 的 double。

- [ ] **Step 1: 写测试（先准备一个 helper 构造灰度图）**

写入 `test/domain/metering/luminance_extractor_test.dart`：

```dart
import 'dart:typed_data';

import 'package:film_go/domain/metering/luminance_extractor.dart';
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造 [w] × [h] 的常量灰度图（每像素相同 [value]）。
Uint8List solid(int w, int h, int value) {
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = value;
  }
  return out;
}

void main() {
  group('LuminanceExtractor.average', () {
    test('纯白整帧均值 = 255', () {
      final v = LuminanceExtractor.extract(
        bytes: solid(160, 120, 255),
        width: 160,
        height: 120,
        bytesPerRow: 160,
        mode: MeterMode.average,
      );
      expect(v, closeTo(255, 1e-9));
    });

    test('纯黑整帧均值 = 0', () {
      final v = LuminanceExtractor.extract(
        bytes: solid(160, 120, 0),
        width: 160,
        height: 120,
        bytesPerRow: 160,
        mode: MeterMode.average,
      );
      expect(v, closeTo(0, 1e-9));
    });

    test('支持 stride > width（行尾 padding）', () {
      // 16x4 实际像素，stride=20（每行末尾 4 字节 padding）
      final bytes = Uint8List(20 * 4);
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 16; x++) {
          bytes[y * 20 + x] = 100;
        }
        // padding 留 0
      }
      final v = LuminanceExtractor.extract(
        bytes: bytes,
        width: 16,
        height: 4,
        bytesPerRow: 20,
        mode: MeterMode.average,
      );
      expect(v, closeTo(100, 1e-9));
    });
  });

  group('LuminanceExtractor.centerWeighted', () {
    test('中心亮、四周暗时，权重偏向中心', () {
      // 100x100 全 50，中心 25x25 改 200
      final w = 100, h = 100;
      final bytes = solid(w, h, 50);
      final cx0 = (w - 25) ~/ 2, cy0 = (h - 25) ~/ 2;
      for (var y = cy0; y < cy0 + 25; y++) {
        for (var x = cx0; x < cx0 + 25; x++) {
          bytes[y * w + x] = 200;
        }
      }
      final v = LuminanceExtractor.extract(
        bytes: bytes,
        width: w,
        height: h,
        bytesPerRow: w,
        mode: MeterMode.centerWeighted,
      );
      // 中心均值 ≈ 200，整帧均值 = 50 + (200-50)·(25·25/10000) = 50 + 9.375 = 59.375
      // 加权 = 200·0.75 + 59.375·0.25 = 150 + 14.84 = 164.84
      expect(v, closeTo(164.84, 0.5));
    });
  });

  group('LuminanceExtractor.spot', () {
    test('只对 spotCenter 处的 5% 方形取均值', () {
      // 200x100，全 50；右下角放 200 的方块（对应 spotCenter≈(0.85, 0.85) 的 5%）
      final w = 200, h = 100;
      final bytes = solid(w, h, 50);
      // 5% of 100 = 5px，那里我们把 (170..174)x(85..89) 设为 200
      for (var y = 85; y < 90; y++) {
        for (var x = 170; x < 175; x++) {
          bytes[y * w + x] = 200;
        }
      }
      final v = LuminanceExtractor.extract(
        bytes: bytes,
        width: w,
        height: h,
        bytesPerRow: w,
        mode: MeterMode.spot,
        spotCenter: const SpotCenter(0.86, 0.87),
      );
      expect(v, greaterThan(150),
          reason: 'spot 集中在 200 区附近，应远高于背景 50');
    });

    test('spot 模式必须传 spotCenter，否则抛 ArgumentError', () {
      expect(
        () => LuminanceExtractor.extract(
          bytes: solid(10, 10, 50),
          width: 10,
          height: 10,
          bytesPerRow: 10,
          mode: MeterMode.spot,
          spotCenter: null,
        ),
        throwsArgumentError,
      );
    });
  });
}
```

- [ ] **Step 2: 看到红**

```bash
flutter test test/domain/metering/luminance_extractor_test.dart
```

- [ ] **Step 3: 写实现**

写入 `lib/domain/metering/luminance_extractor.dart`：

```dart
import 'dart:typed_data';

import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:meta/meta.dart';

/// 点测的归一化中心点（0..1）。
@immutable
class SpotCenter {
  const SpotCenter(this.x, this.y);
  final double x;
  final double y;
}

/// 从灰度缓冲区按测光模式提取平均亮度（0..255）。
///
/// Camera 插件给 Android YUV420 时第一个 plane 即 Y；iOS BGRA 需要在 Service
/// 层先转灰度后再传进来。本类纯 Dart，不依赖任何 Flutter / dart:ui，可在
/// isolate 中调用。
class LuminanceExtractor {
  const LuminanceExtractor._();

  static double extract({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    required MeterMode mode,
    SpotCenter? spotCenter,
  }) {
    return switch (mode) {
      MeterMode.average => _rectMean(bytes, bytesPerRow, 0, 0, width, height),
      MeterMode.centerWeighted => _centerWeighted(bytes, width, height, bytesPerRow),
      MeterMode.spot => _spot(bytes, width, height, bytesPerRow, spotCenter),
    };
  }

  static double _rectMean(
    Uint8List bytes,
    int stride,
    int x0,
    int y0,
    int w,
    int h,
  ) {
    if (w <= 0 || h <= 0) return 0;
    var sum = 0;
    for (var y = y0; y < y0 + h; y++) {
      final rowStart = y * stride;
      for (var x = x0; x < x0 + w; x++) {
        sum += bytes[rowStart + x];
      }
    }
    return sum / (w * h);
  }

  static double _centerWeighted(
    Uint8List bytes,
    int width,
    int height,
    int stride,
  ) {
    final cw = (width * 0.5).round();
    final ch = (height * 0.5).round();
    final cx0 = (width - cw) ~/ 2;
    final cy0 = (height - ch) ~/ 2;
    final centerMean = _rectMean(bytes, stride, cx0, cy0, cw, ch);
    final fullMean = _rectMean(bytes, stride, 0, 0, width, height);
    return centerMean * 0.75 + fullMean * 0.25;
  }

  static double _spot(
    Uint8List bytes,
    int width,
    int height,
    int stride,
    SpotCenter? center,
  ) {
    if (center == null) {
      throw ArgumentError.value(
          center, 'spotCenter', 'MeterMode.spot 必须提供 spotCenter');
    }
    final shortSide = width < height ? width : height;
    final size = (shortSide * 0.05).round().clamp(1, shortSide);
    final cx = (center.x * width).round();
    final cy = (center.y * height).round();
    var x0 = cx - size ~/ 2;
    var y0 = cy - size ~/ 2;
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x0 + size > width) x0 = width - size;
    if (y0 + size > height) y0 = height - size;
    return _rectMean(bytes, stride, x0, y0, size, size);
  }
}
```

> 0.5×0.5 ≈ 25% 中心矩形对应中央重点的中央区。

- [ ] **Step 4: 看到绿**

```bash
flutter test test/domain/metering/luminance_extractor_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/domain/metering/luminance_extractor.dart test/domain/metering/luminance_extractor_test.dart
git commit -m "feat: 增加 LuminanceExtractor（支持点测/中央重点/平均）"
```

---

## Task 4: Domain — 亮度→EV 换算

**Files:**
- Create: `lib/domain/metering/luminance_to_ev.dart`
- Create: `test/domain/metering/luminance_to_ev_test.dart`

**公式：** 反射光测光 `EV = log2(L · K / (ISO · S))`，其中 `K=12.5`（常数），`S` = sensor sensitivity，缺省取 `1`，整体偏移用 `calibrationOffset` 补偿（用户首次校准时存）。

实际相机拿到的 `L` 是 0..255 的灰度均值，需要先线性化到 `0..1`（除 255）。

- [ ] **Step 1: 写测试**

写入 `test/domain/metering/luminance_to_ev_test.dart`：

```dart
import 'package:film_go/domain/metering/luminance_to_ev.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LuminanceToEv.fromGrayMean', () {
    test('ISO 翻倍等价于 EV +1', () {
      final atIso100 = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      final atIso200 = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: const IsoValue(200),
        calibrationOffset: 0,
      );
      // EV ∝ log2(K/ISO)：ISO 翻倍意味着同样亮度需要少 1 EV 曝光，
      // 但本工具返回的是"测得的 EV"，ISO 高 = 等效 EV 高 +1
      expect(atIso200 - atIso100, closeTo(1.0, 1e-9));
    });

    test('grayMean 翻倍等价于 EV +1', () {
      final atDim = LuminanceToEv.fromGrayMean(
        grayMean: 64,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      final atBright = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      expect(atBright - atDim, closeTo(1.0, 1e-9));
    });

    test('校准偏移直接加到结果上', () {
      final base = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      final tuned = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: const IsoValue(100),
        calibrationOffset: 1.5,
      );
      expect(tuned - base, closeTo(1.5, 1e-9));
    });

    test('grayMean=0 安全返回低值（不抛 NaN）', () {
      final v = LuminanceToEv.fromGrayMean(
        grayMean: 0,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      expect(v.isFinite, isTrue);
      expect(v, lessThan(-10), reason: '完全黑应给一个非常低的 EV');
    });
  });

  group('LuminanceToEv.calibrationOffsetFor', () {
    test('给定 grayMean/ISO 与目标 EV，反推偏移使结果对齐', () {
      const iso = IsoValue(100);
      const grayMean = 128;
      const targetEv = 12.0;
      final offset = LuminanceToEv.calibrationOffsetFor(
        grayMean: grayMean,
        iso: iso,
        targetEv: targetEv,
      );
      final ev = LuminanceToEv.fromGrayMean(
        grayMean: grayMean,
        iso: iso,
        calibrationOffset: offset,
      );
      expect(ev, closeTo(targetEv, 1e-6));
    });
  });
}
```

- [ ] **Step 2: 看到红**

```bash
flutter test test/domain/metering/luminance_to_ev_test.dart
```

- [ ] **Step 3: 写实现**

写入 `lib/domain/metering/luminance_to_ev.dart`：

```dart
import 'dart:math' as math;

import 'package:film_go/domain/shared/iso_value.dart';

/// 反射光亮度（0..255 灰度均值）→ EV 换算。
///
/// 公式（反射光测光基线）：
///   EV = log2(L_norm · K / (1)) + log2(ISO/100)
/// 其中 L_norm = grayMean/255，K=12.5，1 是 sensor sensitivity 缺省值。
/// `calibrationOffset` 由用户在已知 EV 场景下校准得出，整体加到结果上。
class LuminanceToEv {
  const LuminanceToEv._();

  /// K：反射光常数（CIPA / ISO 2720 标准）。
  static const double k = 12.5;

  /// 防止 grayMean=0 时 log2 = -∞，加一个极小 floor。
  static const double _grayFloor = 0.5;

  static double fromGrayMean({
    required num grayMean,
    required IsoValue iso,
    required double calibrationOffset,
  }) {
    final clamped = grayMean < _grayFloor ? _grayFloor : grayMean.toDouble();
    final lNorm = clamped / 255.0;
    final base = math.log(lNorm * k) / math.ln2;
    final isoTerm = math.log(iso.value / 100) / math.ln2;
    return base + isoTerm + calibrationOffset;
  }

  /// 反推：给定 grayMean/ISO 与"参考 EV"，返回需要的偏移使结果落在 targetEv。
  static double calibrationOffsetFor({
    required num grayMean,
    required IsoValue iso,
    required double targetEv,
  }) {
    final raw = fromGrayMean(
      grayMean: grayMean,
      iso: iso,
      calibrationOffset: 0,
    );
    return targetEv - raw;
  }
}
```

- [ ] **Step 4: 看到绿**

```bash
flutter test test/domain/metering/luminance_to_ev_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/domain/metering/luminance_to_ev.dart test/domain/metering/luminance_to_ev_test.dart
git commit -m "feat: 实现 LuminanceToEv（K=12.5 反射光公式 + 校准偏移）"
```

---

## Task 5: Domain — MeterReading 值对象

**Files:**
- Create: `lib/domain/metering/meter_reading.dart`
- Create: `test/domain/metering/meter_reading_test.dart`

**用途：** 一次测光的快照——EV、ISO、模式、来源、时间戳。送入 controller 用，UI 也直接消费。

- [ ] **Step 1: 写测试**

写入 `test/domain/metering/meter_reading_test.dart`：

```dart
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeterReading', () {
    test('字段保留与相等性', () {
      final at = DateTime(2026, 5, 24, 12);
      final r = MeterReading(
        ev: 14.5,
        iso: const IsoValue(100),
        mode: MeterMode.centerWeighted,
        source: MeterSource.camera,
        takenAt: at,
      );
      expect(r.ev, 14.5);
      expect(r.iso.value, 100);
      expect(r.mode, MeterMode.centerWeighted);
      expect(r.source, MeterSource.camera);
      expect(r.takenAt, at);
    });

    test('copyWith 不影响其他字段', () {
      final r = MeterReading(
        ev: 14.5,
        iso: const IsoValue(100),
        mode: MeterMode.average,
        source: MeterSource.manual,
        takenAt: DateTime(2026),
      );
      final updated = r.copyWith(ev: 15);
      expect(updated.ev, 15);
      expect(updated.iso, r.iso);
      expect(updated.mode, r.mode);
      expect(updated.source, r.source);
      expect(updated.takenAt, r.takenAt);
    });
  });

  group('MeterSource', () {
    test('display 中文标签', () {
      expect(MeterSource.camera.display, '相机');
      expect(MeterSource.lightSensor.display, '传感器');
      expect(MeterSource.manual.display, '手动');
    });
  });
}
```

- [ ] **Step 2: 看到红**

```bash
flutter test test/domain/metering/meter_reading_test.dart
```

- [ ] **Step 3: 写实现**

写入 `lib/domain/metering/meter_reading.dart`：

```dart
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:meta/meta.dart';

/// 一次测光的来源。
enum MeterSource {
  camera,
  lightSensor,
  manual;

  String get display => switch (this) {
        MeterSource.camera => '相机',
        MeterSource.lightSensor => '传感器',
        MeterSource.manual => '手动',
      };
}

@immutable
class MeterReading {
  const MeterReading({
    required this.ev,
    required this.iso,
    required this.mode,
    required this.source,
    required this.takenAt,
  });

  final double ev;
  final IsoValue iso;
  final MeterMode mode;
  final MeterSource source;
  final DateTime takenAt;

  MeterReading copyWith({
    double? ev,
    IsoValue? iso,
    MeterMode? mode,
    MeterSource? source,
    DateTime? takenAt,
  }) {
    return MeterReading(
      ev: ev ?? this.ev,
      iso: iso ?? this.iso,
      mode: mode ?? this.mode,
      source: source ?? this.source,
      takenAt: takenAt ?? this.takenAt,
    );
  }
}
```

- [ ] **Step 4: 看到绿**

```bash
flutter test test/domain/metering/meter_reading_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/domain/metering/meter_reading.dart test/domain/metering/meter_reading_test.dart
git commit -m "feat: 增加 MeterReading 值对象与 MeterSource 枚举"
```

---

## Task 6: 添加 M1 测光新依赖

**Files:**
- Modify: `pubspec.yaml`

新增依赖：
- `camera ^0.11.0`：取景帧
- `light ^3.0.1`：Android ALS lux
- `permission_handler ^11.3.1`：运行时权限
- `shared_preferences ^2.3.2`：校准偏移持久化

- [ ] **Step 1: 修改 dependencies**

把 `pubspec.yaml` 中的 `dependencies` 段（保留已有项）调整为：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.0
  google_fonts: ^6.2.1
  meta: ^1.15.0
  phosphor_flutter: ^2.1.0
  camera: ^0.11.0
  light: ^3.0.1
  permission_handler: ^11.3.1
  shared_preferences: ^2.3.2
```

- [ ] **Step 2: 拉依赖**

```bash
flutter pub get
```
Expected: 成功，无依赖冲突。若 light 与目标 SDK 不匹配，回退到 `light: ^3.0.0`；若仍冲突记 issue 后此 task 暂停。

- [ ] **Step 3: 跑 analyze 确认**

```bash
flutter analyze
```
Expected: No issues found!

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: 引入 camera/light/permission_handler/shared_preferences 依赖"
```

---

## Task 7: iOS 与 Android 平台权限声明

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`

**iOS：** 仅相机权限。光线传感器在 iOS 上不可用，不需要声明。

**Android：** CAMERA + 可选的 light sensor（不需声明 permission，但要声明 feature 不强制）。

- [ ] **Step 1: 修改 iOS Info.plist**

在 `ios/Runner/Info.plist` 的根 `<dict>` 中新增（如已存在则跳过）：

```xml
<key>NSCameraUsageDescription</key>
<string>Film Go 使用相机进行取景测光，不会拍摄或上传任何照片。</string>
```

- [ ] **Step 2: 修改 Android Manifest**

打开 `android/app/src/main/AndroidManifest.xml`，在 `<manifest>` 顶部 `<application>` 之外新增：

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.sensor.light" android:required="false" />
```

- [ ] **Step 3: 跑 analyze（不会跑模拟器，但能检查 Dart 侧无破坏）**

```bash
flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git add ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "chore: 声明 iOS/Android 相机权限与光线传感器特性"
```

---

## Task 8: 校准持久化 CalibrationStore

**Files:**
- Create: `lib/services/calibration_store.dart`
- Create: `test/services/calibration_store_test.dart`

**职责：** 用 SharedPreferences 存一个 double `calibrationOffset`，缺省 0。

- [ ] **Step 1: 写测试（用 SharedPreferences 的 mock）**

写入 `test/services/calibration_store_test.dart`：

```dart
import 'package:film_go/services/calibration_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CalibrationStore', () {
    test('未设置时返回 0', () async {
      final s = await CalibrationStore.create();
      expect(s.read(), 0);
    });

    test('write 后再 read 能取回相同值', () async {
      final s = await CalibrationStore.create();
      await s.write(1.5);
      expect(s.read(), 1.5);
    });

    test('clear 复位回 0', () async {
      final s = await CalibrationStore.create();
      await s.write(2.0);
      await s.clear();
      expect(s.read(), 0);
    });
  });
}
```

- [ ] **Step 2: 看到红**

```bash
flutter test test/services/calibration_store_test.dart
```

- [ ] **Step 3: 写实现**

写入 `lib/services/calibration_store.dart`：

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// 持久化测光校准偏移（EV 单位）。
class CalibrationStore {
  CalibrationStore._(this._prefs);

  static const _key = 'meter.calibration.offset.ev';

  final SharedPreferences _prefs;

  static Future<CalibrationStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CalibrationStore._(prefs);
  }

  double read() => _prefs.getDouble(_key) ?? 0.0;

  Future<void> write(double offset) async {
    await _prefs.setDouble(_key, offset);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
```

- [ ] **Step 4: 看到绿**

```bash
flutter test test/services/calibration_store_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/services/calibration_store.dart test/services/calibration_store_test.dart
git commit -m "feat: 增加 CalibrationStore（SharedPreferences 持久化校准偏移）"
```

---

## Task 9: 相机服务 CameraService

**Files:**
- Create: `lib/services/camera_service.dart`

**职责：** 封装 `camera` 插件——枚举后置相机、初始化预览（720p 上限）、`startImageStream` 把帧 callback 出来；统一把 iOS BGRA 与 Android YUV420 转成"灰度 Uint8List + width + height + bytesPerRow"。**Domain 层的 LuminanceExtractor 才是真正算亮度的；这里只做格式归一化。**

> ⚠️ camera 插件 API：iOS 给 `ImageFormatGroup.bgra8888`，Android 给 `yuv420`。BGRA 转灰度公式：`Y = 0.299·R + 0.587·G + 0.114·B`（与 BT.601 一致）。YUV420 第一个 plane 直接是 Y。

不在这一层启动 isolate；调用方（controller）拿到帧后用 `compute()` 把 LuminanceExtractor 的调用扔进 isolate。

- [ ] **Step 1: 写实现（不写单测：插件依赖平台，单测意义不大；后面用 controller 集成验证）**

写入 `lib/services/camera_service.dart`：

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// 相机帧的灰度归一化结果。
@immutable
class GrayFrame {
  const GrayFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
  });
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;
}

/// 取景测光相机服务。
///
/// 生命周期：[initialize] → [start] → 监听 [frames] → [stop] → [dispose]
class CameraService {
  CameraController? _controller;
  StreamController<GrayFrame>? _framesCtrl;
  bool _streaming = false;

  CameraDescription? _camera;

  Future<bool> initialize() async {
    final cams = await availableCameras();
    final back = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.isNotEmpty ? cams.first : throw StateError('无可用相机'),
    );
    _camera = back;
    _controller = CameraController(
      back,
      ResolutionPreset.medium, // 480p 量级，测光不需要高分辨率
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    return true;
  }

  CameraController? get controller => _controller;

  Stream<GrayFrame> frames() {
    _framesCtrl ??= StreamController<GrayFrame>.broadcast();
    return _framesCtrl!.stream;
  }

  Future<void> start() async {
    if (_controller == null || _streaming) return;
    _framesCtrl ??= StreamController<GrayFrame>.broadcast();
    await _controller!.startImageStream(_onImage);
    _streaming = true;
  }

  Future<void> stop() async {
    if (_controller == null || !_streaming) return;
    await _controller!.stopImageStream();
    _streaming = false;
  }

  Future<void> dispose() async {
    await stop();
    await _controller?.dispose();
    await _framesCtrl?.close();
    _controller = null;
    _framesCtrl = null;
  }

  void _onImage(CameraImage image) {
    final ctrl = _framesCtrl;
    if (ctrl == null || ctrl.isClosed) return;
    final gray = _toGray(image);
    if (gray != null) {
      ctrl.add(gray);
    }
  }

  GrayFrame? _toGray(CameraImage image) {
    final w = image.width;
    final h = image.height;
    if (image.format.group == ImageFormatGroup.yuv420) {
      final y = image.planes.first;
      return GrayFrame(
        bytes: Uint8List.fromList(y.bytes),
        width: w,
        height: h,
        bytesPerRow: y.bytesPerRow,
      );
    }
    if (image.format.group == ImageFormatGroup.bgra8888) {
      final p = image.planes.first;
      final stride = p.bytesPerRow;
      final src = p.bytes;
      final out = Uint8List(w * h);
      for (var row = 0; row < h; row++) {
        for (var col = 0; col < w; col++) {
          final i = row * stride + col * 4;
          final b = src[i];
          final g = src[i + 1];
          final r = src[i + 2];
          // BT.601
          out[row * w + col] = (0.299 * r + 0.587 * g + 0.114 * b).round();
        }
      }
      return GrayFrame(
        bytes: out,
        width: w,
        height: h,
        bytesPerRow: w,
      );
    }
    return null;
  }
}
```

- [ ] **Step 2: 跑 analyze 确认无 lint**

```bash
flutter analyze lib/services/camera_service.dart
```
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add lib/services/camera_service.dart
git commit -m "feat: 增加 CameraService（YUV/BGRA 归一化为灰度帧）"
```

---

## Task 10: 光线传感器服务 LightSensorService

**Files:**
- Create: `lib/services/light_sensor_service.dart`

**职责：** 包装 `light` 插件，仅 Android 可用。提供：
- `isAvailable()` — Android 设备且有 ALS 才返回 true
- `lux()` — Stream\<int>

**Lux → EV 公式：** `EV = log2(lux / 2.5) + log2(ISO/100)` （入射光测光，K=2.5；与反射光不一样）。这一层不做换算，只暴露 lux 流，由 controller 调用 domain 层 `LuminanceToEv` 的同名 helper。但因 lux 已经是绝对量纲，需要在 LuminanceToEv 中加一个 `fromLux` 方法。

> 为避免触发 LuminanceToEv 的二次改动，本 task 的实现先只暴露 lux stream，**EV 换算放在下一个 task 里补**。

- [ ] **Step 1: 写实现**

写入 `lib/services/light_sensor_service.dart`：

```dart
import 'dart:async';
import 'dart:io';

import 'package:light/light.dart';

/// 光线传感器服务（仅 Android）。
class LightSensorService {
  Light? _light;
  StreamSubscription<int>? _sub;
  StreamController<int>? _luxCtrl;

  bool isAvailable() => Platform.isAndroid;

  Stream<int> lux() {
    _luxCtrl ??= StreamController<int>.broadcast();
    if (_sub == null && isAvailable()) {
      _light ??= Light();
      try {
        _sub = _light!.lightSensorStream.listen(
          (v) => _luxCtrl?.add(v),
          onError: (_) {},
        );
      } catch (_) {
        // 设备无 ALS 时插件抛错，吞掉
      }
    }
    return _luxCtrl!.stream;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _luxCtrl?.close();
    _sub = null;
    _luxCtrl = null;
  }
}
```

- [ ] **Step 2: 跑 analyze**

```bash
flutter analyze lib/services/light_sensor_service.dart
```
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add lib/services/light_sensor_service.dart
git commit -m "feat: 增加 LightSensorService（Android ALS lux 流）"
```

---

## Task 11: Domain — Lux → EV (入射光测光)

**Files:**
- Modify: `lib/domain/metering/luminance_to_ev.dart`
- Modify: `test/domain/metering/luminance_to_ev_test.dart`

**公式：** 入射光测光 `EV = log2(lux / C) + log2(ISO/100)`，C=2.5。

- [ ] **Step 1: 在测试文件追加分组**

在 `test/domain/metering/luminance_to_ev_test.dart` 的 `void main()` 里追加：

```dart
  group('LuminanceToEv.fromLux', () {
    test('lux 翻倍等价于 EV +1', () {
      final dim = LuminanceToEv.fromLux(
        lux: 100,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      final bright = LuminanceToEv.fromLux(
        lux: 200,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      expect(bright - dim, closeTo(1.0, 1e-9));
    });

    test('lux=2.5, ISO 100, offset 0 → EV 0', () {
      final ev = LuminanceToEv.fromLux(
        lux: 2.5,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      expect(ev, closeTo(0, 1e-9));
    });

    test('lux<=0 安全返回低值不抛 NaN', () {
      final v = LuminanceToEv.fromLux(
        lux: 0,
        iso: const IsoValue(100),
        calibrationOffset: 0,
      );
      expect(v.isFinite, isTrue);
    });
  });
```

- [ ] **Step 2: 看到红**

```bash
flutter test test/domain/metering/luminance_to_ev_test.dart
```

- [ ] **Step 3: 在实现里追加**

修改 `lib/domain/metering/luminance_to_ev.dart`，在 class 内追加：

```dart
  /// 入射光测光常数（CIPA / ISO 2720）。
  static const double cIncident = 2.5;

  /// 防止 lux=0 的 floor。
  static const double _luxFloor = 0.01;

  /// EV (入射光) = log2(lux / C) + log2(ISO/100) + offset
  static double fromLux({
    required num lux,
    required IsoValue iso,
    required double calibrationOffset,
  }) {
    final clamped = lux < _luxFloor ? _luxFloor : lux.toDouble();
    final base = math.log(clamped / cIncident) / math.ln2;
    final isoTerm = math.log(iso.value / 100) / math.ln2;
    return base + isoTerm + calibrationOffset;
  }
```

- [ ] **Step 4: 看到绿**

```bash
flutter test test/domain/metering/luminance_to_ev_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/domain/metering/luminance_to_ev.dart test/domain/metering/luminance_to_ev_test.dart
git commit -m "feat: LuminanceToEv 增加 fromLux 入射光换算"
```

---

## Task 12: MeterController — state model

**Files:**
- Create: `lib/pages/meter/controller/meter_state.dart`

**职责：** 描述 Meter 页面的不可变状态：当前 ISO / 模式 / 来源 / 当前 EV / 锁定 EV / 校准偏移 / 错误信息 / 是否已校准。

- [ ] **Step 1: 写实现（无独立测试，覆盖会在 controller 测试里）**

写入 `lib/pages/meter/controller/meter_state.dart`：

```dart
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:meta/meta.dart';

@immutable
class MeterState {
  const MeterState({
    required this.iso,
    required this.mode,
    required this.source,
    required this.calibrationOffset,
    this.lastReading,
    this.lockedEv,
    this.errorMessage,
    this.permissionGranted = false,
  });

  factory MeterState.initial() => const MeterState(
        iso: IsoValue(400),
        mode: MeterMode.centerWeighted,
        source: MeterSource.manual,
        calibrationOffset: 0,
      );

  final IsoValue iso;
  final MeterMode mode;
  final MeterSource source;
  final double calibrationOffset;
  final MeterReading? lastReading;
  final double? lockedEv;
  final String? errorMessage;
  final bool permissionGranted;

  /// 当前实际用于推荐曝光组合的 EV：优先 locked，其次 lastReading.ev。
  double? get effectiveEv => lockedEv ?? lastReading?.ev;

  MeterState copyWith({
    IsoValue? iso,
    MeterMode? mode,
    MeterSource? source,
    double? calibrationOffset,
    MeterReading? lastReading,
    Object? lockedEv = _sentinel,
    Object? errorMessage = _sentinel,
    bool? permissionGranted,
  }) {
    return MeterState(
      iso: iso ?? this.iso,
      mode: mode ?? this.mode,
      source: source ?? this.source,
      calibrationOffset: calibrationOffset ?? this.calibrationOffset,
      lastReading: lastReading ?? this.lastReading,
      lockedEv: identical(lockedEv, _sentinel)
          ? this.lockedEv
          : lockedEv as double?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }
}

const Object _sentinel = Object();
```

- [ ] **Step 2: 跑 analyze**

```bash
flutter analyze lib/pages/meter/controller/meter_state.dart
```
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add lib/pages/meter/controller/meter_state.dart
git commit -m "feat: 增加 MeterState（ISO/模式/来源/锁定 EV）"
```

---

## Task 13: MeterController — Notifier

**Files:**
- Create: `lib/pages/meter/controller/meter_controller.dart`
- Create: `test/pages/meter/meter_controller_test.dart`

**职责：** Riverpod `Notifier`。对外暴露：
- `setIso(IsoValue)` / `setMode(MeterMode)` / `setSource(MeterSource)`
- `setManualEv(double)` — manual 模式下直接更新 lastReading
- `lock()` / `unlock()` — toggle lockedEv = lastReading?.ev
- `applyCalibration({grayMean, targetEv})` — 反推 offset 并保存
- `processCameraFrame(GrayFrame, [SpotCenter])` — 由 page 在帧到来时调
- `processLux(num lux)` — 由 page 在 sensor 流到来时调

> Service（CameraService / LightSensorService / CalibrationStore）通过构造函数注入，便于单测用 fake。

- [ ] **Step 1: 写测试（用 fake CalibrationStore + 直接喂 GrayFrame）**

写入 `test/pages/meter/meter_controller_test.dart`：

```dart
import 'dart:typed_data';

import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCalibrationStore implements CalibrationStoreLike {
  double _v = 0;
  @override
  double read() => _v;
  @override
  Future<void> write(double v) async => _v = v;
  @override
  Future<void> clear() async => _v = 0;
}

GrayFrame _solid(int w, int h, int v) {
  final b = Uint8List(w * h);
  for (var i = 0; i < b.length; i++) {
    b[i] = v;
  }
  return GrayFrame(bytes: b, width: w, height: h, bytesPerRow: w);
}

void main() {
  group('MeterController', () {
    late MeterController c;
    late _FakeCalibrationStore store;

    setUp(() {
      store = _FakeCalibrationStore();
      c = MeterController(store: store);
      c.bootstrap();
    });

    test('初始状态：ISO 400 / 中央重点 / 手动', () {
      expect(c.state.iso.value, 400);
      expect(c.state.mode, MeterMode.centerWeighted);
      expect(c.state.source, MeterSource.manual);
    });

    test('setManualEv 更新 lastReading 与 source', () {
      c.setManualEv(13.5);
      expect(c.state.lastReading?.ev, 13.5);
      expect(c.state.source, MeterSource.manual);
    });

    test('lock 把当前 lastReading 的 EV 冻结到 lockedEv', () {
      c.setManualEv(12);
      c.lock();
      expect(c.state.lockedEv, 12);
      // 之后 lastReading 变化不应改变 lockedEv
      c.setManualEv(15);
      expect(c.state.lockedEv, 12);
      expect(c.state.effectiveEv, 12);
    });

    test('unlock 清除 lockedEv', () {
      c.setManualEv(12);
      c.lock();
      c.unlock();
      expect(c.state.lockedEv, isNull);
    });

    test('processCameraFrame 在 average 模式下计算 EV', () {
      c.setMode(MeterMode.average);
      c.setSource(MeterSource.camera);
      c.processCameraFrame(_solid(100, 100, 128));
      expect(c.state.lastReading, isNotNull);
      expect(c.state.lastReading!.source, MeterSource.camera);
      expect(c.state.lastReading!.ev.isFinite, isTrue);
    });

    test('processLux 计算 EV', () {
      c.setSource(MeterSource.lightSensor);
      c.processLux(2.5);
      expect(c.state.lastReading, isNotNull);
      // lux=2.5 ISO 100 → 0；ISO 400 → +2
      expect(c.state.lastReading!.ev, closeTo(2, 1e-6));
    });

    test('applyCalibration 反推偏移并保存', () async {
      c.setMode(MeterMode.average);
      c.setSource(MeterSource.camera);
      // 先喂一帧 grayMean=128, ISO=400
      c.processCameraFrame(_solid(10, 10, 128));
      final raw = c.state.lastReading!.ev;
      // 用户告诉 App 当前实际 EV = 12
      await c.applyCalibrationFromLastReading(targetEv: 12);
      expect(c.state.calibrationOffset, closeTo(12 - raw, 1e-6));
      expect(store.read(), c.state.calibrationOffset);
      // 再喂同样一帧，结果应等于 12
      c.processCameraFrame(_solid(10, 10, 128));
      expect(c.state.lastReading!.ev, closeTo(12, 1e-6));
    });
  });
}
```

- [ ] **Step 2: 看到红**

```bash
flutter test test/pages/meter/meter_controller_test.dart
```

- [ ] **Step 3: 写实现（含 CalibrationStoreLike 抽象）**

修改 `lib/services/calibration_store.dart`，在文件顶部加抽象：

```dart
abstract interface class CalibrationStoreLike {
  double read();
  Future<void> write(double offset);
  Future<void> clear();
}
```

并把 `class CalibrationStore` 改为 `class CalibrationStore implements CalibrationStoreLike`。

写入 `lib/pages/meter/controller/meter_controller.dart`：

```dart
import 'package:film_go/domain/metering/luminance_extractor.dart';
import 'package:film_go/domain/metering/luminance_to_ev.dart';
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeterController extends ChangeNotifier {
  MeterController({required CalibrationStoreLike store}) : _store = store {
    _state = MeterState.initial();
  }

  final CalibrationStoreLike _store;
  late MeterState _state;
  MeterState get state => _state;

  void _set(MeterState s) {
    _state = s;
    notifyListeners();
  }

  void bootstrap() {
    _set(_state.copyWith(calibrationOffset: _store.read()));
  }

  // ----- setters -----

  void setIso(IsoValue iso) => _set(_state.copyWith(iso: iso));
  void setMode(MeterMode mode) => _set(_state.copyWith(mode: mode));
  void setSource(MeterSource source) => _set(_state.copyWith(source: source));

  void setManualEv(double ev) {
    _set(_state.copyWith(
      source: MeterSource.manual,
      lastReading: MeterReading(
        ev: ev,
        iso: _state.iso,
        mode: _state.mode,
        source: MeterSource.manual,
        takenAt: DateTime.now(),
      ),
    ));
  }

  // ----- lock -----

  void lock() {
    final ev = _state.lastReading?.ev;
    if (ev == null) return;
    _set(_state.copyWith(lockedEv: ev));
  }

  void unlock() {
    _set(_state.copyWith(lockedEv: null));
  }

  // ----- camera / sensor inputs -----

  /// 设置最近一次帧的 grayMean，用于校准时反推偏移。
  num? _lastGrayMean;

  void processCameraFrame(GrayFrame frame, {SpotCenter? spotCenter}) {
    final mean = LuminanceExtractor.extract(
      bytes: frame.bytes,
      width: frame.width,
      height: frame.height,
      bytesPerRow: frame.bytesPerRow,
      mode: _state.mode,
      spotCenter: spotCenter ?? const SpotCenter(0.5, 0.5),
    );
    _lastGrayMean = mean;
    final ev = LuminanceToEv.fromGrayMean(
      grayMean: mean,
      iso: _state.iso,
      calibrationOffset: _state.calibrationOffset,
    );
    _set(_state.copyWith(
      source: MeterSource.camera,
      lastReading: MeterReading(
        ev: ev,
        iso: _state.iso,
        mode: _state.mode,
        source: MeterSource.camera,
        takenAt: DateTime.now(),
      ),
    ));
  }

  void processLux(num lux) {
    final ev = LuminanceToEv.fromLux(
      lux: lux,
      iso: _state.iso,
      calibrationOffset: _state.calibrationOffset,
    );
    _set(_state.copyWith(
      source: MeterSource.lightSensor,
      lastReading: MeterReading(
        ev: ev,
        iso: _state.iso,
        mode: _state.mode,
        source: MeterSource.lightSensor,
        takenAt: DateTime.now(),
      ),
    ));
  }

  // ----- calibration -----

  Future<void> applyCalibrationFromLastReading({required double targetEv}) async {
    final mean = _lastGrayMean;
    if (mean == null) return;
    final offset = LuminanceToEv.calibrationOffsetFor(
      grayMean: mean,
      iso: _state.iso,
      targetEv: targetEv,
    );
    await _store.write(offset);
    _set(_state.copyWith(calibrationOffset: offset));
    // 用新偏移立即重算最近一次读数
    _set(_state.copyWith(
      lastReading: _state.lastReading?.copyWith(ev: targetEv),
    ));
  }

  Future<void> resetCalibration() async {
    await _store.clear();
    _set(_state.copyWith(calibrationOffset: 0));
  }
}

final meterControllerProvider = ChangeNotifierProvider<MeterController>((ref) {
  // 真实的 CalibrationStore 由调用方在 main 里 override
  throw UnimplementedError(
      'meterControllerProvider 必须在 ProviderScope 中 override');
});
```

- [ ] **Step 4: 看到绿**

```bash
flutter test test/pages/meter/meter_controller_test.dart
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/pages/meter/controller/meter_controller.dart lib/services/calibration_store.dart test/pages/meter/meter_controller_test.dart
git commit -m "feat: 增加 MeterController（ISO/模式/来源/锁定/校准）"
```

---

## Task 14: 在 main.dart 注入真实 CalibrationStore

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 改 main.dart 让 ProviderScope 携带 override**

```dart
import 'package:film_go/app.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await CalibrationStore.create();
  runApp(
    ProviderScope(
      overrides: [
        meterControllerProvider.overrideWith(
          (ref) => MeterController(store: store)..bootstrap(),
        ),
      ],
      child: const FilmGoApp(),
    ),
  );
}
```

- [ ] **Step 2: 跑 analyze + 全量测试**

```bash
flutter analyze && flutter test
```
Expected: 全绿（widget 冒烟测试此前会通过 ProviderScope 进入，会触发 unimplemented；下一步修复）。

> 如果 widget 冒烟测试因 unimplemented 失败，是预期的——下一个 task 修。

- [ ] **Step 3: 修 widget_test.dart**

修改 `test/widget_test.dart`，把 `ProviderScope(child: FilmGoApp())` 替换为带 override 的版本：

```dart
import 'package:film_go/app.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements CalibrationStoreLike {
  @override
  double read() => 0;
  @override
  Future<void> write(double offset) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('App 启动后默认进入 Meter Tab', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meterControllerProvider.overrideWith(
            (ref) => MeterController(store: _FakeStore())..bootstrap(),
          ),
        ],
        child: const FilmGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('取景'), findsOneWidget);
    expect(find.text('计算'), findsOneWidget);
    expect(find.text('胶卷'), findsOneWidget);
    expect(find.text('暗房'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('点击「计算」Tab 切换到 Calc 页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meterControllerProvider.overrideWith(
            (ref) => MeterController(store: _FakeStore())..bootstrap(),
          ),
        ],
        child: const FilmGoApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('计算'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Calc'), findsOneWidget);
  });
}
```

- [ ] **Step 4: 跑全量**

```bash
flutter analyze && flutter test
```
Expected: All tests passed!

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat: main.dart 在 ProviderScope 注入 CalibrationStore"
```

---

## Task 15: UI — EV 大数字读出 EvReadout

**Files:**
- Create: `lib/pages/meter/widgets/ev_readout.dart`

**职责：** 把当前 EV（含 source 标签、锁定指示）渲染成大数字。

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/ev_readout.dart`：

```dart
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

class EvReadout extends StatelessWidget {
  const EvReadout({
    required this.ev,
    required this.sourceLabel,
    this.locked = false,
    super.key,
  });

  final double? ev;
  final String sourceLabel;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final value = ev?.toStringAsFixed(1) ?? '--';
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'EV $value',
          style: tt.displayMedium?.copyWith(
            fontWeight: FontWeight.w300,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sourceLabel,
              style: tt.labelMedium?.copyWith(color: AppColors.gray500),
            ),
            if (locked) ...[
              const SizedBox(width: 8),
              const Icon(Icons.lock, size: 14, color: AppColors.gray500),
            ],
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: analyze**

```bash
flutter analyze lib/pages/meter/widgets/ev_readout.dart
```
Expected: No issues found!

- [ ] **Step 3: Commit**

```bash
git add lib/pages/meter/widgets/ev_readout.dart
git commit -m "feat: 增加 EvReadout 大数字读出组件"
```

---

## Task 16: UI — ISO 选择器 IsoSelector

**Files:**
- Create: `lib/pages/meter/widgets/iso_selector.dart`

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/iso_selector.dart`：

```dart
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter/material.dart';

class IsoSelector extends StatelessWidget {
  const IsoSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IsoValue value;
  final ValueChanged<IsoValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final iso in IsoValue.fullStops)
          ChoiceChip(
            label: Text(iso.value.toString()),
            selected: iso == value,
            onSelected: (s) {
              if (s) onChanged(iso);
            },
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: analyze**

```bash
flutter analyze lib/pages/meter/widgets/iso_selector.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/meter/widgets/iso_selector.dart
git commit -m "feat: 增加 IsoSelector（整档 ISO ChoiceChip）"
```

---

## Task 17: UI — 模式选择器 ModeSelector

**Files:**
- Create: `lib/pages/meter/widgets/mode_selector.dart`

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/mode_selector.dart`：

```dart
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final MeterMode value;
  final ValueChanged<MeterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MeterMode>(
      segments: [
        for (final m in MeterMode.values)
          ButtonSegment(value: m, label: Text(m.display)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
```

- [ ] **Step 2: analyze + commit**

```bash
flutter analyze lib/pages/meter/widgets/mode_selector.dart
git add lib/pages/meter/widgets/mode_selector.dart
git commit -m "feat: 增加 ModeSelector（点测/中央重点/平均切换）"
```

---

## Task 18: UI — 来源选择器 SourceSelector

**Files:**
- Create: `lib/pages/meter/widgets/source_selector.dart`

**特性：** lightSensor 在 iOS 上不可用 → 显示但置灰禁用。

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/source_selector.dart`：

```dart
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:flutter/material.dart';

class SourceSelector extends StatelessWidget {
  const SourceSelector({
    required this.value,
    required this.onChanged,
    required this.sensorAvailable,
    super.key,
  });

  final MeterSource value;
  final ValueChanged<MeterSource> onChanged;
  final bool sensorAvailable;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MeterSource>(
      segments: [
        for (final s in MeterSource.values)
          ButtonSegment(
            value: s,
            label: Text(s.display),
            enabled: s != MeterSource.lightSensor || sensorAvailable,
          ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
```

- [ ] **Step 2: analyze + commit**

```bash
flutter analyze lib/pages/meter/widgets/source_selector.dart
git add lib/pages/meter/widgets/source_selector.dart
git commit -m "feat: 增加 SourceSelector（相机/传感器/手动；iOS 屏蔽传感器）"
```

---

## Task 19: UI — 手动 EV 输入对话框 ManualEvDialog

**Files:**
- Create: `lib/pages/meter/widgets/manual_ev_dialog.dart`

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/manual_ev_dialog.dart`：

```dart
import 'package:flutter/material.dart';

class ManualEvDialog extends StatefulWidget {
  const ManualEvDialog({this.initialEv, super.key});
  final double? initialEv;

  static Future<double?> show(BuildContext context, {double? initialEv}) {
    return showDialog<double>(
      context: context,
      builder: (_) => ManualEvDialog(initialEv: initialEv),
    );
  }

  @override
  State<ManualEvDialog> createState() => _ManualEvDialogState();
}

class _ManualEvDialogState extends State<ManualEvDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialEv?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动输入 EV'),
      content: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: const InputDecoration(hintText: '例如 12.5'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_ctrl.text.trim());
            if (v != null) Navigator.pop(context, v);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: analyze + commit**

```bash
flutter analyze lib/pages/meter/widgets/manual_ev_dialog.dart
git add lib/pages/meter/widgets/manual_ev_dialog.dart
git commit -m "feat: 增加 ManualEvDialog（手动输入 EV）"
```

---

## Task 20: UI — 锁定按钮 LockButton

**Files:**
- Create: `lib/pages/meter/widgets/lock_button.dart`

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/lock_button.dart`：

```dart
import 'package:flutter/material.dart';

class LockButton extends StatelessWidget {
  const LockButton({
    required this.locked,
    required this.onToggle,
    super.key,
  });

  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onToggle,
      icon: Icon(locked ? Icons.lock : Icons.lock_open),
      label: Text(locked ? '已锁定' : '锁定 EV'),
    );
  }
}
```

- [ ] **Step 2: analyze + commit**

```bash
flutter analyze lib/pages/meter/widgets/lock_button.dart
git add lib/pages/meter/widgets/lock_button.dart
git commit -m "feat: 增加 LockButton（锁定/解锁 EV）"
```

---

## Task 21: UI — 曝光组合列表 ExposurePairList

**Files:**
- Create: `lib/pages/meter/widgets/exposure_pair_list.dart`

**职责：** 把 `EvCalculator.suggestPairs(...)` 输出渲染为横滑列表。

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/exposure_pair_list.dart`：

```dart
import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ExposurePairList extends StatelessWidget {
  const ExposurePairList({required this.pairs, super.key});

  final List<ExposurePair> pairs;

  @override
  Widget build(BuildContext context) {
    if (pairs.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('—')),
      );
    }
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pairs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = pairs[i];
          return Container(
            width: 88,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gray300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p.aperture.display,
                    style: Theme.of(context).textTheme.titleMedium),
                Text(p.shutter.display,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: analyze + commit**

```bash
flutter analyze lib/pages/meter/widgets/exposure_pair_list.dart
git add lib/pages/meter/widgets/exposure_pair_list.dart
git commit -m "feat: 增加 ExposurePairList（横滑光圈—快门组合）"
```

---

## Task 22: UI — 测光表盘 MeterDial（CustomPainter）

**Files:**
- Create: `lib/pages/meter/widgets/meter_dial.dart`

**职责：** 模仿手持测光表的圆形扇形刻度——把 EV ∈ [-3, 18] 映射到 -π·5/6 到 π·5/6 的角度，绘制刻度与指针。

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/meter_dial.dart`：

```dart
import 'dart:math' as math;

import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

class MeterDial extends StatelessWidget {
  const MeterDial({required this.ev, super.key});

  final double? ev;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: const Size.square(220),
      painter: _DialPainter(
        ev: ev,
        fg: isDark ? AppColors.white : AppColors.black,
        muted: AppColors.gray500,
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.ev, required this.fg, required this.muted});
  final double? ev;
  final Color fg;
  final Color muted;

  static const double _minEv = -3;
  static const double _maxEv = 18;
  static const double _arc = math.pi * 5 / 3; // 300°

  double _angleFor(double ev) {
    final t = ((ev - _minEv) / (_maxEv - _minEv)).clamp(0.0, 1.0);
    return -_arc / 2 + t * _arc - math.pi / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;

    final ringPaint = Paint()
      ..color = muted.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, r, ringPaint);

    // 刻度：每整 EV 一根，每 5 EV 加粗
    for (var v = _minEv.toInt(); v <= _maxEv.toInt(); v++) {
      final a = _angleFor(v.toDouble());
      final outer = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      final inner = Offset(
        center.dx + (r - (v % 5 == 0 ? 14 : 8)) * math.cos(a),
        center.dy + (r - (v % 5 == 0 ? 14 : 8)) * math.sin(a),
      );
      final p = Paint()
        ..color = v % 5 == 0 ? fg : muted
        ..strokeWidth = v % 5 == 0 ? 2 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, p);
      if (v % 5 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$v',
            style: TextStyle(color: fg, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lp = Offset(
          center.dx + (r - 24) * math.cos(a) - tp.width / 2,
          center.dy + (r - 24) * math.sin(a) - tp.height / 2,
        );
        tp.paint(canvas, lp);
      }
    }

    // 指针
    final v = ev;
    if (v != null) {
      final a = _angleFor(v);
      final tip = Offset(
        center.dx + (r - 4) * math.cos(a),
        center.dy + (r - 4) * math.sin(a),
      );
      final p = Paint()
        ..color = fg
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, tip, p);
      canvas.drawCircle(center, 4, p..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.ev != ev;
}
```

- [ ] **Step 2: analyze + commit**

```bash
flutter analyze lib/pages/meter/widgets/meter_dial.dart
git add lib/pages/meter/widgets/meter_dial.dart
git commit -m "feat: 增加 MeterDial 圆形测光表盘（CustomPainter）"
```

---

## Task 23: UI — 校准对话框 CalibrationDialog

**Files:**
- Create: `lib/pages/meter/widgets/calibration_dialog.dart`

**职责：** 让用户填一个"参考 EV"。出现条件：用户点了"校准"按钮，且当前 source=camera/lightSensor。

- [ ] **Step 1: 写实现**

写入 `lib/pages/meter/widgets/calibration_dialog.dart`：

```dart
import 'package:flutter/material.dart';

class CalibrationDialog extends StatefulWidget {
  const CalibrationDialog({super.key});

  static Future<double?> show(BuildContext context) {
    return showDialog<double>(
      context: context,
      builder: (_) => const CalibrationDialog(),
    );
  }

  @override
  State<CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<CalibrationDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('校准测光'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('对准已知 EV 的稳定光源（如阳光直射纸面、Sunny 16 速查），输入参考 EV：'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(hintText: '例如 15'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_ctrl.text.trim());
            if (v != null) Navigator.pop(context, v);
          },
          child: const Text('校准'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: analyze + commit**

```bash
flutter analyze lib/pages/meter/widgets/calibration_dialog.dart
git add lib/pages/meter/widgets/calibration_dialog.dart
git commit -m "feat: 增加 CalibrationDialog（首次校准入口）"
```

---

## Task 24: 整合 — 重写 MeterPage

**Files:**
- Modify: `lib/pages/meter/meter_page.dart`
- Create: `test/pages/meter/meter_page_smoke_test.dart`

**职责：** 把上面所有部件串起来。本 task 暂不接相机/传感器实物流（避免阻塞测试），只布局 + 接 controller，相机帧/lux 流接入下一个 task。

- [ ] **Step 1: 重写 MeterPage**

写入 `lib/pages/meter/meter_page.dart`：

```dart
import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/widgets/calibration_dialog.dart';
import 'package:film_go/pages/meter/widgets/ev_readout.dart';
import 'package:film_go/pages/meter/widgets/exposure_pair_list.dart';
import 'package:film_go/pages/meter/widgets/iso_selector.dart';
import 'package:film_go/pages/meter/widgets/lock_button.dart';
import 'package:film_go/pages/meter/widgets/manual_ev_dialog.dart';
import 'package:film_go/pages/meter/widgets/meter_dial.dart';
import 'package:film_go/pages/meter/widgets/mode_selector.dart';
import 'package:film_go/pages/meter/widgets/source_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeterPage extends ConsumerWidget {
  const MeterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(meterControllerProvider);
    final state = c.state;
    final pairs = state.effectiveEv == null
        ? const <ExposurePair>[]
        : EvCalculator.suggestPairs(
            ev: state.effectiveEv!,
            iso: state.iso.value,
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('取景测光'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '校准',
            onPressed: () async {
              final target = await CalibrationDialog.show(context);
              if (target != null) {
                await c.applyCalibrationFromLastReading(targetEv: target);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              MeterDial(ev: state.effectiveEv),
              const SizedBox(height: 8),
              EvReadout(
                ev: state.effectiveEv,
                sourceLabel: state.source.display,
                locked: state.lockedEv != null,
              ),
              const SizedBox(height: 16),
              ExposurePairList(pairs: pairs),
              const SizedBox(height: 16),
              SourceSelector(
                value: state.source,
                sensorAvailable: false, // 真实判断在下一 task 里接入
                onChanged: (s) => c.setSource(s),
              ),
              const SizedBox(height: 12),
              ModeSelector(
                value: state.mode,
                onChanged: (m) => c.setMode(m),
              ),
              const SizedBox(height: 12),
              IsoSelector(
                value: state.iso,
                onChanged: (i) => c.setIso(i),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('手动输入'),
                      onPressed: () async {
                        final v = await ManualEvDialog.show(
                          context,
                          initialEv: state.effectiveEv,
                        );
                        if (v != null) c.setManualEv(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LockButton(
                      locked: state.lockedEv != null,
                      onToggle: () =>
                          state.lockedEv != null ? c.unlock() : c.lock(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 写 smoke test**

写入 `test/pages/meter/meter_page_smoke_test.dart`：

```dart
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/meter_page.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStore implements CalibrationStoreLike {
  @override
  double read() => 0;
  @override
  Future<void> write(double offset) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('MeterPage 渲染并响应手动输入', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meterControllerProvider.overrideWith(
            (ref) => MeterController(store: _FakeStore())..bootstrap(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MeterPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('取景测光'), findsOneWidget);
    expect(find.textContaining('EV'), findsWidgets);
    expect(find.text('手动'), findsWidgets);
    expect(find.text('点测'), findsOneWidget);

    // 点手动输入
    await tester.tap(find.text('手动输入'));
    await tester.pumpAndSettle();
    expect(find.text('手动输入 EV'), findsOneWidget);

    // 输入 12 → 确定
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.textContaining('EV 12'), findsOneWidget);
  });
}
```

- [ ] **Step 3: 跑 analyze + 全测试**

```bash
flutter analyze && flutter test
```
Expected: All tests passed!

- [ ] **Step 4: Commit**

```bash
git add lib/pages/meter/meter_page.dart test/pages/meter/meter_page_smoke_test.dart
git commit -m "feat: MeterPage 整合 dial/readout/selectors/pairs/手动输入/锁定/校准"
```

---

## Task 25: 接入相机帧流

**Files:**
- Modify: `lib/pages/meter/meter_page.dart`

**目标：** 当 source=camera 时启动 CameraService，把帧丢进 controller；source 切换或离开页面时停止。

- [ ] **Step 1: 把 MeterPage 改为 ConsumerStatefulWidget，引入 CameraService 生命周期**

替换 `lib/pages/meter/meter_page.dart`，**保留所有已有 UI**，外壳改为：

```dart
import 'dart:async';

import 'package:camera/camera.dart' show CameraPreview;
import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/widgets/calibration_dialog.dart';
import 'package:film_go/pages/meter/widgets/ev_readout.dart';
import 'package:film_go/pages/meter/widgets/exposure_pair_list.dart';
import 'package:film_go/pages/meter/widgets/iso_selector.dart';
import 'package:film_go/pages/meter/widgets/lock_button.dart';
import 'package:film_go/pages/meter/widgets/manual_ev_dialog.dart';
import 'package:film_go/pages/meter/widgets/meter_dial.dart';
import 'package:film_go/pages/meter/widgets/mode_selector.dart';
import 'package:film_go/pages/meter/widgets/source_selector.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class MeterPage extends ConsumerStatefulWidget {
  const MeterPage({super.key});

  @override
  ConsumerState<MeterPage> createState() => _MeterPageState();
}

class _MeterPageState extends ConsumerState<MeterPage> {
  CameraService? _camera;
  StreamSubscription<GrayFrame>? _frameSub;
  MeterSource? _wiredSource;

  @override
  void dispose() {
    _frameSub?.cancel();
    unawaited(_camera?.dispose());
    super.dispose();
  }

  Future<void> _wireCamera() async {
    if (_camera != null) return;
    final granted = await Permission.camera.request().isGranted;
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未授予相机权限，已退回手动模式')),
        );
        ref.read(meterControllerProvider).setSource(MeterSource.manual);
      }
      return;
    }
    final svc = CameraService();
    try {
      await svc.initialize();
      await svc.start();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机初始化失败：$e')),
        );
        ref.read(meterControllerProvider).setSource(MeterSource.manual);
      }
      await svc.dispose();
      return;
    }
    _camera = svc;
    _frameSub = svc.frames().listen((frame) {
      ref.read(meterControllerProvider).processCameraFrame(frame);
    });
    if (mounted) setState(() {});
  }

  Future<void> _unwireCamera() async {
    await _frameSub?.cancel();
    _frameSub = null;
    await _camera?.dispose();
    _camera = null;
    if (mounted) setState(() {});
  }

  Future<void> _onSourceChanged(MeterSource s) async {
    ref.read(meterControllerProvider).setSource(s);
    if (s == MeterSource.camera) {
      await _wireCamera();
    } else {
      await _unwireCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(meterControllerProvider);
    final state = c.state;
    if (_wiredSource != state.source) {
      _wiredSource = state.source;
    }
    final pairs = state.effectiveEv == null
        ? const <ExposurePair>[]
        : EvCalculator.suggestPairs(
            ev: state.effectiveEv!,
            iso: state.iso.value,
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('取景测光'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '校准',
            onPressed: () async {
              final target = await CalibrationDialog.show(context);
              if (target != null) {
                await c.applyCalibrationFromLastReading(targetEv: target);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (state.source == MeterSource.camera &&
                  _camera?.controller?.value.isInitialized == true)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: CameraPreview(_camera!.controller!),
                )
              else
                const SizedBox(height: 8),
              MeterDial(ev: state.effectiveEv),
              const SizedBox(height: 8),
              EvReadout(
                ev: state.effectiveEv,
                sourceLabel: state.source.display,
                locked: state.lockedEv != null,
              ),
              const SizedBox(height: 16),
              ExposurePairList(pairs: pairs),
              const SizedBox(height: 16),
              SourceSelector(
                value: state.source,
                sensorAvailable: defaultTargetPlatform == TargetPlatform.android,
                onChanged: _onSourceChanged,
              ),
              const SizedBox(height: 12),
              ModeSelector(
                value: state.mode,
                onChanged: (m) => c.setMode(m),
              ),
              const SizedBox(height: 12),
              IsoSelector(
                value: state.iso,
                onChanged: (i) => c.setIso(i),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('手动输入'),
                      onPressed: () async {
                        final v = await ManualEvDialog.show(
                          context,
                          initialEv: state.effectiveEv,
                        );
                        if (v != null) c.setManualEv(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LockButton(
                      locked: state.lockedEv != null,
                      onToggle: () =>
                          state.lockedEv != null ? c.unlock() : c.lock(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 跑 analyze + 全测试**

```bash
flutter analyze && flutter test
```
Expected: All tests passed!（已有 smoke test 保持兼容，因 source 默认是 manual 不会触发相机）

- [ ] **Step 3: Commit**

```bash
git add lib/pages/meter/meter_page.dart
git commit -m "feat: MeterPage 接入相机帧流（含权限请求）"
```

---

## Task 26: 接入光线传感器流（Android）

**Files:**
- Modify: `lib/pages/meter/meter_page.dart`

- [ ] **Step 1: 在 _MeterPageState 顶部追加字段**

```dart
  LightSensorService? _light;
  StreamSubscription<int>? _luxSub;
```

并在文件 import 区追加：
```dart
import 'package:film_go/services/light_sensor_service.dart';
```

- [ ] **Step 2: 增加 wire/unwire 方法**

在 `_unwireCamera` 之后追加：

```dart
  Future<void> _wireLight() async {
    if (_light != null) return;
    final svc = LightSensorService();
    if (!svc.isAvailable()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备无光线传感器')),
        );
        ref.read(meterControllerProvider).setSource(MeterSource.manual);
      }
      return;
    }
    _light = svc;
    _luxSub = svc.lux().listen((lux) {
      ref.read(meterControllerProvider).processLux(lux);
    });
    if (mounted) setState(() {});
  }

  Future<void> _unwireLight() async {
    await _luxSub?.cancel();
    _luxSub = null;
    await _light?.dispose();
    _light = null;
    if (mounted) setState(() {});
  }
```

- [ ] **Step 3: 在 dispose 中加一行**

```dart
  @override
  void dispose() {
    _frameSub?.cancel();
    _luxSub?.cancel();
    unawaited(_camera?.dispose());
    unawaited(_light?.dispose());
    super.dispose();
  }
```

- [ ] **Step 4: 更新 _onSourceChanged**

```dart
  Future<void> _onSourceChanged(MeterSource s) async {
    ref.read(meterControllerProvider).setSource(s);
    if (s == MeterSource.camera) {
      await _unwireLight();
      await _wireCamera();
    } else if (s == MeterSource.lightSensor) {
      await _unwireCamera();
      await _wireLight();
    } else {
      await _unwireCamera();
      await _unwireLight();
    }
  }
```

- [ ] **Step 5: 跑 analyze + 全测试**

```bash
flutter analyze && flutter test
```
Expected: All tests passed!

- [ ] **Step 6: Commit**

```bash
git add lib/pages/meter/meter_page.dart
git commit -m "feat: MeterPage 接入 Android 光线传感器流"
```

---

## Task 27: 收尾验证 + Tag

- [ ] **Step 1: 跑全套静态检查**

```bash
dart format --output=none --set-exit-if-changed . && flutter analyze --fatal-infos && flutter test
```
Expected: 全绿。如果 format 失败，运行 `dart format .` 后再 add/commit："chore: dart format 整理"。

- [ ] **Step 2: 列出所有新增 commit 检查 type 前缀**

```bash
git log --oneline 8ef0fc8..HEAD
```
Expected: 全部以 `feat:` / `chore:` / `docs:` / `test:` / `refactor:` 开头，不漏 `:`。

- [ ] **Step 3: 打 tag**

```bash
git tag -a film-go-m1-meter -m "Film Go M1 metering complete"
git tag -l 'film-go-*'
```
Expected: 输出包含 `film-go-m0` 和 `film-go-m1-meter`。

---

## 验收清单（M1 测光完成判据）

- [ ] `flutter analyze --fatal-infos` 全绿
- [ ] `flutter test` 全绿，覆盖：
  - IsoValue / MeterMode / MeterReading
  - LuminanceExtractor（含三种模式 + stride）
  - LuminanceToEv（fromGrayMean + fromLux + 校准）
  - CalibrationStore
  - MeterController（ISO/模式/来源/锁定/校准/相机帧/lux）
  - MeterPage smoke（默认渲染 + 手动输入流程）
- [ ] 真机/模拟器跑 `flutter run`：
  - 进入 Meter Tab，看到表盘 + EV --
  - 切到"手动" → 输入 12 → 看到 EV 12 + 推荐组合
  - 锁定 → ISO 改成 800 → 推荐组合按 ISO 800 更新但 EV 仍 12
  - 切到"相机"（Android 真机/iOS 真机）→ 授权后画面出现，EV 实时刷新
  - Android 真机切到"传感器" → EV 由 lux 计算
  - 点右上角"调试/校准"图标 → 输入参考 EV → 当前 EV 立即对齐
- [ ] commit 历史每条都有 type 前缀；tag `film-go-m1-meter` 已打
