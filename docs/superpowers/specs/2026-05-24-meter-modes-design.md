# 测光页改版：快速 / 专业双模式 + 测光准确度修复

> 日期：2026-05-24
> 状态：Draft，待用户审阅
> 作者：兆兆 + Claude
> 范围：仅 Meter 页（不涉及 Calc / Rolls / Darkroom / Me）

---

## 一、背景与目标

### 1.1 问题

当前 `MeterPage` 是单页面 + 多 selector 的"设置面板"风格：相机预览 + 圆形表盘 + 横滑曝光对 + ISO/模式/来源 三个 SegmentedButton + 手动 EV 输入对话框 + 校准对话框。问题集中在三处：

1. **测光不准**：`EV = log2((grayMean/255) · K) + log2(ISO/100) + offset` 这个公式在相机 AE 开启时近乎失效——AE 永远把画面拉向中灰，`grayMean` 几乎不携带场景绝对亮度信息。
2. **交互不顺手**：扫街场景需要"小窗预览 + 一键看曝光对"，专业摄影场景又需要"全屏取景 + 点哪测哪 + 拍照留底"，单一布局两头不讨好。
3. **EV 用具体小数**：`12.5` `15.3` 这种数字对胶片用户没意义；摄影圈通用单位是档位（stops）和 1/3 增量。

### 1.2 目标

- **快速测光（Quick）**：图1 风格，小窗预览 + 左侧 ISO/光圈 双列竖标尺 + 4 列滚轮（EV100/ISO/COMP/FILTER）+ 锁定按钮。扫街用。
- **专业测光（Pro）**：图2 风格，全屏取景 + 顶部 ISO/EV 状态栏 + 点哪重对焦+测光 + 三种测光模式循环切换 + 底部刻度尺 + 主组合大字读数 + 圆形快门按钮（按下=拍照保存到系统相册带水印）。
- **EV 档位化**：不再展示具体 EV 数值；EV 补偿仅以 1/3 stop 为步长，范围 ±3 stop。
- **测光精度**：按业界主流方案重写公式，引入相机自报的 ISO/exposureTime/aperture，目标精度 ±0.3 stop。

### 1.3 不在本期范围

- 胶卷曲线互易律修正（Frame log 流程的事）
- CPL / 彩色滤镜补偿（FILTER 列只支持 ND）
- 装饰元素：图2 中 `Leica M3` `Porta 400` `2:3` `35mm` 等（v2 的「胶片质感装饰层」）
- 色温 6200K（需 WB metadata，工程量另算）
- Zone System 多点测光导出（需要新建专用页面）

---

## 二、整体结构

### 2.1 入口与切换

底部 Tab「取景」打开 `MeterPage`：
- 顶部一个浮在内容上方的胶囊分段切换 `[⚡ 快速 │ 🎯 专业]`，默认快速
- 切换由 `IndexedStack` 持有两个子页面，避免重建相机会话
- Quick 背景使用主题底色；Pro 背景纯黑（含状态栏）

### 2.2 状态划分

```
MeterController (ChangeNotifier, 单例 Provider)
├─ shared:  IsoValue iso, String? filmId,
│           double calibrationOffset
├─ quick:   QuickModeState
│             ├─ EvStop comp
│             ├─ NdFilter filter
│             ├─ double? lockedEv  (EV100, 1/3 stop snapped)
│             └─ MeterReading? metered
└─ pro:     ProModeState
              ├─ EvStop comp
              ├─ NdFilter filter
              ├─ MeterMode meterMode  (spot/center/eval)
              ├─ Offset spotCenter   (0..1)
              └─ MeterReading? metered
```

切换 tab 不触发 `CameraService` / `CameraMetadataChannel` 拆装；`MeterController` 在切换时调整 ROI 计算路径与 AE Lock 行为即可。

### 2.3 文件清单

**新建**

| 路径 | 作用 |
|---|---|
| `lib/domain/shared/ev_stop.dart` | 1/3 stop 步长的档位值对象 |
| `lib/domain/shared/nd_filter.dart` | ND2..ND1024 枚举 + stops |
| `lib/services/camera_metadata_channel.dart` | 平台通道 Dart 接口 |
| `lib/services/camera_capture_service.dart` | 拍照 + 水印 + 入相册 |
| `lib/services/watermark_renderer.dart` | 纯 image 包水印合成 |
| `android/app/src/main/kotlin/com/zhaoo/filmgo/CameraMetadataPlugin.kt` | Android Camera2 metadata + AE lock |
| `ios/Runner/CameraMetadataPlugin.swift` | iOS AVFoundation metadata + AE lock |
| `lib/pages/meter/quick/quick_meter_view.dart` | 快速测光页 |
| `lib/pages/meter/pro/pro_meter_view.dart` | 专业测光页 |
| `lib/pages/meter/widgets/mode_tab.dart` | 顶部胶囊分段切换 |
| `lib/pages/meter/widgets/dual_scale.dart` | 快速：左侧双列竖标尺 |
| `lib/pages/meter/widgets/quick_drum.dart` | 快速：4 列滚轮 |
| `lib/pages/meter/widgets/measure_icon_button.dart` | 快速：锁定按钮 |
| `lib/pages/meter/pro/widgets/pro_top_status_bar.dart` | 专业：ISO + EV 顶栏 |
| `lib/pages/meter/pro/widgets/pro_preview_layer.dart` | 专业：全屏预览 + 点击 |
| `lib/pages/meter/pro/widgets/spot_overlay.dart` | 专业：黄色测光框 |
| `lib/pages/meter/pro/widgets/scale_strip.dart` | 专业：底部 f/t 刻度尺 |
| `lib/pages/meter/pro/widgets/pro_readout.dart` | 专业：左下大字组合 |
| `lib/pages/meter/pro/widgets/shutter_button.dart` | 专业：圆形快门按钮 |
| `lib/pages/meter/pro/widgets/meter_mode_cycle_button.dart` | 专业：右下循环切换 |

**重写**

| 路径 | 改动 |
|---|---|
| `lib/pages/meter/meter_page.dart` | 顶部 tab + IndexedStack |
| `lib/pages/meter/controller/meter_controller.dart` | 状态分 shared/quick/pro 三块 |
| `lib/pages/meter/controller/meter_state.dart` | 拆 `QuickModeState` / `ProModeState` |
| `lib/domain/metering/luminance_to_ev.dart` | 新公式（见 §3） |
| `lib/domain/metering/luminance_extractor.dart` | YUV limited range + sRGB 反 gamma |
| `lib/domain/shared/iso_value.dart` | 增加 `thirdStops` 序列 |
| `lib/services/camera_service.dart` | 修复预览拉伸 + 接 metadata channel |

**删除**

`manual_ev_dialog.dart` `mode_selector.dart` `source_selector.dart` `meter_dial.dart` `ev_readout.dart` `lock_button.dart` `iso_selector.dart` `exposure_pair_list.dart`（功能由新控件覆盖）。

---

## 三、测光准确度修复

### 3.1 根因

相机 AE 始终把画面调向中灰，`grayMean/255` 几乎是常量；当前公式没有相机自身曝光参数（N/t/ISO_sensor），无法做绝对计算。叠加 sRGB gamma 没反解 + YUV limited range 没修正 + tonemap/WB/cos⁴ 等 ISP 影响，整体偏差可达 ±2 stop。

### 3.2 新公式（Dart 侧）

`lib/domain/metering/luminance_to_ev.dart` 重写为：

```dart
/// 输入：相机当前帧的曝光参数 + 该帧 ROI 的归一化线性灰度
/// 输出：场景 EV100（与 ISO 无关的统一 EV）
EV100 = log2(N² / t)
      − log2(sensorIso / 100)
      + log2(yLinear / 0.18)
      + calibrationOffset

// 用于推荐曝光对的最终 EV
EV_eff = EV100 + log2(ISO_film / 100) − COMP − FILTER_stops
```

`yLinear` 的取值流程（`luminance_extractor.dart` 重写）：
1. 按测光模式取 ROI（spot 5% / center 25%+边缘 / eval 全帧，复用现有逻辑）
2. **YUV limited range 修正**：`y = clamp((Y − 16) / 219, 0, 1)`
3. **BGRA**：`y = 0.2126R + 0.7152G + 0.0722B`（先归一化到 0..1）
4. **sRGB 反 gamma**：
   ```
   yLinear = (y ≤ 0.04045) ? y / 12.92
                           : pow((y + 0.055) / 1.055, 2.4)
   ```

### 3.3 平台通道：`CameraMetadataChannel`

**Dart 接口**

```dart
class CameraMetadataFrame {
  final int sensorIso;
  final double exposureSec;
  final double aperture;       // 手机后置定光圈
  final bool aeConverged;
  final int timestampUs;
}

class CameraMetadataChannel {
  Stream<CameraMetadataFrame> frames();
  Future<void> lockAE();
  Future<void> unlockAE();
  Future<void> setMeteringPoint(double x, double y);  // 0..1
  Future<bool> isSupported();  // 检测 hw level
}
```

**Android（Kotlin）**

复用 `camera` 插件已开的 `CameraDevice` / `CaptureSession`（通过 cameraId 共享）：
- 注册 `CaptureCallback`，`onCaptureCompleted` 里读：
  - `SENSOR_SENSITIVITY` (Int)
  - `SENSOR_EXPOSURE_TIME` (Long, ns)
  - `LENS_APERTURE` (Float)
  - `CONTROL_AE_STATE`
- `EventChannel` 推流给 Dart
- AE Lock：`CONTROL_AE_LOCK = true`
- 检测：`CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL >= FULL`，否则 `isSupported() = false`

**iOS（Swift）**

- KVO 监听 `AVCaptureDevice.iso`、`exposureDuration`、`lensAperture`
- AE Lock：`device.exposureMode = .locked` + `lockForConfiguration { ... }`
- AE 收敛：`device.isAdjustingExposure == false`

**复用现有 session**：`camera` 插件不直接暴露 `CameraCaptureSession` / `AVCaptureDeviceInput`，但可以通过 `cameraId`（Android）/ `position`（iOS）反查到同一设备实例并附加 capture callback。开 Open Camera 等开源项目的常见做法。

### 3.4 校准流程

保留 `CalibrationStore`，`CalibrationDialog` 重构为分两步的 BottomSheet：
1. 「对准 18% 灰卡 / 阳光直射纸面」提示 + 实时预览缩略图
2. 输入参考 EV（默认 15，附 Sunny 16 速查表，用户可点选「晴天=15 / 多云=14 / 阴天=13 / 阴影=12 / 室内窗边=10」）
3. 点击校准 → 用当前帧的 ISO + ExposureTime + grayLinear 反推 offset → 写入 store

### 3.5 降级路径

如果原生通道在某机型读不到 metadata（极少数老 Android 不支持 Camera2 Level FULL）：
- `CameraMetadataChannel.isSupported()` 返回 false
- Dart 侧使用降级公式：`EV100_fallback = log2(yLinear · 12.5 · 100) + calibrationOffset`
  （等价于把"中灰对应 EV100=0"作为参考点的纯反射光估计；无相机参数补偿，需依赖用户校准）
- UI 横幅提示「此设备测光精度受限，建议手动校准」
- 不抛错，不阻塞用户

---

## 四、快速测光页

### 4.1 布局

```
┌──────────────────────────────────────────┐
│           [⚡ Quick │ 🎯 Pro]   (浮顶)    │
│  ┌────┬────┐  ┌──────────────────────┐   │
│  │ T  │ N  │  │                      │   │
│  │1/4k│    │  │    相机预览           │   │
│  │1/2k│1.4 │  │   (BoxFit.cover,     │   │
│  │1/1k│ 2  │  │    比例随预览)        │   │
│  │1/500│2.8│  │                      │   │
│  │1/250│ 4 │  │                      │   │
│  │1/125│5.6│  │                      │   │
│  │... │... │  └──────────────────────┘   │
│  │    │    │  ┌──────────────────────┐   │
│  │    │    │  │       📸  (lock)     │   │
│  └────┴────┘  └──────────────────────┘   │
│  ┌──────┬──────┬──────┬──────┐           │
│  │EV100 │ ISO  │ COMP │FILTER│           │
│  │ 9    │ 100  │ −1/3 │  0   │           │
│  │ 10█  │ 125█ │  0█  │  0█  │  ←高亮档  │
│  │ 11   │ 160  │ +1/3 │ ND2  │           │
│  └──────┴──────┴──────┴──────┘           │
└──────────────────────────────────────────┘
```

### 4.2 双列竖标尺 `DualScale`

- 不接收滚动手势（`IgnorePointer`），是**结果显示**
- 数据：`EvCalculator.suggestPairs(EV_eff, iso)` 纵向呈现
- 左列 = 快门 denominator（`1/8000` … `30s`），右列 = 光圈（`1.4` … `32`）
- 中央行（与 drum ISO 对应的那一对）加粗 + 描边
- 随 EV_eff 改变，整体上下平移（200ms ease）

### 4.3 4 列滚轮 `QuickDrum`

四个独立 `ListWheelScrollView`（`perspective: 0`、`diameterRatio: 100` → 视觉平面），共用 `itemExtent = 40`。中心行用一条圆角棕色背景条横贯四列高亮。

| 列 | 数据源 | 显示样例 |
|---|---|---|
| EV100 | 整数 `−3..20` | `9` `10` `11` |
| ISO | `IsoValue.thirdStops` | `100` `125` `160` |
| COMP | `EvStop` 1/3 stop −3..+3（19 档） | `−1`、`−2/3`、`−1/3`、`0`、`+1/3` |
| FILTER | `NdFilter` 枚举 | `0` `ND2` `ND4` … `ND1024` |

### 4.4 数据流

```
每一帧 GrayFrame + CameraMetadataFrame
  └→ MeterController.processFrame()
     ├─ 算 EV100_live (= §3.2 公式，连续 double)
     ├─ 若 quickState.lockedEv == null:
     │   quickState.metered.evHundredInt = round(EV100_live)        // 整数，给 EV100 列
     │   quickState.metered.evHundredFrac = EV100_live − evHundredInt // 小数残差只用于 EV_eff
     └─ EV_eff = (lockedEv ?? (evHundredInt + evHundredFrac))
                + log2(ISO_film / 100) − COMP_stops − FILTER_stops
     └→ EvCalculator.suggestPairs(EV_eff, ISO_film) → DualScale
     └→ drum 四列 controller.animateTo() (EV100 列只动整数位)
```

用户滚动 drum：
- **EV100 列滚动** → `lockedEv = newValue`（自动锁定）→ 📸 按钮变实心
- **ISO / COMP / FILTER 列滚动** → 直接改 state → 重算 pairs
- 📸 点击 → 已锁定就 `lockedEv = null` 解锁；未锁定就 `lockedEv = metered.ev` 锁定 + `HapticFeedback.lightImpact`

### 4.5 控件拆分

```
quick/quick_meter_view.dart         (Stack 布局, ~120 行)
widgets/dual_scale.dart             (CustomPaint, ~150 行)
widgets/quick_drum.dart             (4 × ListWheelScrollView, ~180 行)
widgets/measure_icon_button.dart    (圆形 IconButton, ~40 行)
```

`MeasureIconButton` 图标：未锁定 `Icons.radio_button_unchecked`，锁定 `Icons.lock_outlined`。

---

## 五、专业测光页

### 5.1 布局

```
┌─────────────────────────────────────────┐
│ ISO 400              EV: −1/3           │  顶部状态栏
│ ┌─────────────────────────────────────┐ │
│ │                                     │ │
│ │         ┌───┐                       │ │
│ │         │ + │  (黄框,点测时显示)     │ │
│ │         └───┘                       │ │
│ │                                     │ │
│ │      ╳ 点击位置: 黄色对焦/测光环      │ │
│ │                                     │ │
│ └─────────────────────────────────────┘ │
│ f/1.4  f/2  ▌f/2.8▌  f/4  f/5.6         │  底部刻度尺
│  1/250    ▌1/125▌    1/60               │
│                                         │
│  1/125             ⭕              ⊕    │  快门读数 / 快门 / 模式循环
│  f/2.8                                  │
│              [⚡ Quick │ 🎯 Pro]         │  顶部 tab 浮顶
└─────────────────────────────────────────┘
```

### 5.2 子组件

| 组件 | 文件 | 说明 |
|---|---|---|
| `ProTopStatusBar` | `pro/widgets/pro_top_status_bar.dart` | 左 `ISO 400`，右 `EV: −1/3`；SafeArea + 顶部 tab 留白 |
| `ProPreviewLayer` | `pro/widgets/pro_preview_layer.dart` | 全屏 `CameraPreview` + `BoxFit.cover` 修复拉伸；`GestureDetector` 收 tap |
| `SpotOverlay` | `pro/widgets/spot_overlay.dart` | 黄色 56×56 测光框；仅点测模式渲染，跟随 `spotCenter` 动画 |
| `ScaleStrip` | `pro/widgets/scale_strip.dart` | 双行刻度（光圈在上，快门在下） |
| `ProReadout` | `pro/widgets/pro_readout.dart` | 左下大字 `1/125 / f/2.8` |
| `ShutterButton` | `pro/widgets/shutter_button.dart` | 圆形白底；按下出动画 + `HapticFeedback.heavy` + 拍照 |
| `MeterModeCycleButton` | `pro/widgets/meter_mode_cycle_button.dart` | 右下；图标随模式变化；点击循环 |

### 5.3 交互细节

**点击预览**（`ProPreviewLayer.onTapDown`）：
- 同时下发 **focusPoint + meteringPoint**（全模式生效）：
  - `controller.setFocusPoint(local01)`
  - `controller.setExposurePoint(local01)`
  - `metadataChannel.setMeteringPoint(local01.dx, local01.dy)`
- 点位绘制扩散环动画（300ms 缩放淡出）
- 不切换测光模式

**点测模式**：
- `spotCenter` 持久化到 `ProModeState`
- 黄框留在屏幕上直到下一次点击或切换模式

**测光模式循环**（右下按钮）：
- `spot → center → eval → spot`
- 切换时图标淡入；立即用新模式重算 EV 一次

**底部刻度尺**：
- 随 EV 变化整体平移（200ms ease）
- 中央指示线对齐当前主组合（取 pairs 中央那一对）

### 5.4 拍照 + 水印

新文件 `lib/services/camera_capture_service.dart`：

```dart
class CameraCaptureService {
  Future<String> captureWithWatermark({
    required CameraController controller,
    required ProMeterReading reading,  // ISO/shutter/aperture/ev/timestamp
  });
}
```

流程：
1. `controller.takePicture()` → `XFile`（jpg）
2. `Isolate.run` 内：`package:image` 解码 → 合成水印 → 编码（JPEG 90）
3. `image_gallery_saver` 写入相册（Android `MediaStore` `Pictures/FilmGo/` / iOS `PhotoKit`）
4. 拍照过程显示加载圈，结束后小 toast 反馈

水印规格（右下角，多行，渲染在 `lib/services/watermark_renderer.dart`）：
```
2026-05-24 09:57
ISO 400 · 1/125 · f/2.8
```
- 字体：JetBrains Mono Regular subset（约 30 KB 进 assets）
- 颜色：白色 + 黑描边（1px）
- 字号：图片短边 × 2.5%
- 内边距：图片短边 × 3%
- 时间：`DateTime.now()` 设备本地时间，格式 `yyyy-MM-dd HH:mm`，无时区显示

**新依赖**

```yaml
image: ^4.1.7
image_gallery_saver: ^2.0.3
```

**权限**
- iOS：`Info.plist` 增加 `NSPhotoLibraryAddUsageDescription`「保存带水印的测光参考照片」
- Android 13+：写相册不需要额外权限（`MediaStore`）

水印配 6 个 golden test（不同分辨率 × 不同时间戳长度）。

### 5.5 Pro 状态独立

`ProMeterState`：
- `MeterMode meterMode`
- `Offset spotCenter` (0..1)
- `EvStop comp`
- `NdFilter filter`
- `MeterReading? metered`

ISO / `calibrationOffset` / `filmId` 走 shared 区。Quick 和 Pro 互不影响 comp / filter / 测光模式。

---

## 六、测试策略

### 6.1 Domain（强制 TDD）

| 模块 | 测试 case |
|---|---|
| `EvStop` | `+1/3 + +1/3 = +2/3`、`+2/3 + +1/3 = +1`、`-1 + +1/3 = -2/3`、19 档 display 全覆盖 |
| `NdFilter` | ND2=1、ND4=2、ND1024=10、none=0；序列长度 |
| `IsoValue.thirdStops` | 共 25 档（25 起到 6400），相邻 ratio ≈ 2^(1/3) |
| `LuminanceToEv.fromCameraFrame` | 已知组合反推 EV：中灰 + 室内（EV ≈ 8）/ 中灰 + 晴天（EV ≈ 15）/ 白纸 / 黑布，至少 6 个 case |
| `LuminanceExtractor.gammaDecoded` | YUV: Y=16 → 0.0、Y=235 → 1.0、Y=125 ≈ 0.498；sRGB 反 gamma：`yLinear(0.461) ≈ 0.18` |
| `EvCalculator` | 已有，复用；增加用 `EvStop` 输入的 wrapper 测试 |

### 6.2 Widget（golden）

每个新 widget 一张 golden，light + dark 各一：
- `QuickDrum` 三种状态：unlocked / locked / mid-scroll
- `SpotOverlay` 在四个屏幕角落位置
- `WatermarkRenderer` 6 张：4K/2K × 时间长度 1/2/3 分钟数

### 6.3 Integration

- Mock `CameraMetadataChannel` 推已知参数序列，断言 EV 输出曲线
- AE Lock 切换 → 后续帧 metadata 是否定值
- 拍照 → 水印 golden 比对 + 文件落到沙盒
- metadata 不可用 → 降级公式不崩

### 6.4 真机回归

- iPhone 14 Pro / 小米 13 / Redmi Note 12（HyperOS 1）三机型
- 用 Sekonic L-308X（如有）或同伴的实体测光表对比 5 个场景，目标 ±0.3 stop

---

## 七、实施顺序

8 个 PR（领域/服务与 UI 可并行）：

| # | PR | 依赖 | 可独立 ship |
|---|---|---|---|
| 1 | Domain：`EvStop` / `NdFilter` / `IsoValue.thirdStops` + tests | — | ✅ |
| 2 | Domain：`LuminanceToEv` 公式重写 + `LuminanceExtractor` gamma 反解 + tests | 1 | ✅ |
| 3 | Service：`CameraMetadataChannel` Dart 接口 + Android Kotlin 实现 | 2 | Android-only |
| 4 | Service：iOS Swift 实现 + 双端 AE Lock | 3 | ✅ |
| 5 | Service：`CameraCaptureService` + `WatermarkRenderer` + 入相册 | — | ✅ |
| 6 | UI：`MeterController` 状态重组 + 顶部 tab + IndexedStack 骨架 | 1 | ✅ |
| 7 | UI：QuickMeterView + DualScale + QuickDrum + MeasureIconButton；删除旧 `meter_dial`/`exposure_pair_list` 等 | 6 | ✅ |
| 8 | UI：ProMeterView + 全套 widgets + 拍照接入；删除剩余旧 widget | 5,6,7 | ✅（最终交付） |

---

## 八、风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| `camera` 插件 cameraId 拿不到原生 device 实例 | 中 | 高 | 先以 `camera ^0.11.x` 源码确认；不行就 fork 该插件加私有 method |
| HyperOS / 老 Android `INFO_SUPPORTED_HARDWARE_LEVEL < FULL` 时 metadata 残缺 | 中 | 中 | 检测 hw level，<FULL 走降级；UI 标注「测光精度受限」 |
| iOS KVO 频率高造成主线程抖动 | 低 | 中 | KVO 节流到 30 Hz；metadata stream 与帧 stream 通过 timestamp 对齐 |
| 拍照水印渲染（同步 image 包）阻塞 UI | 中 | 低 | `Isolate.run`；拍照过程显示加载圈 |
| `image_gallery_saver` 在 Android 14 / iOS 17 行为变化（scoped storage） | 中 | 中 | 替代候选 `gal: ^2.x`；早测试，权限文案预审 |
| 顶部 tab 浮层与系统状态栏 / 刘海 / 灵动岛 重叠 | 低 | 低 | `SafeArea(top: true)` + `MediaQuery.padding.top` |

---

## 九、参考资料

- ISO 2720:1974 — General purpose photographic exposure meters
- Wikipedia: "Light meter"、"APEX system"、"Exposure value"
- Android Camera2: `CaptureRequest.SENSOR_SENSITIVITY` / `SENSOR_EXPOSURE_TIME` / `CONTROL_AE_MODE`
- Apple AVFoundation: `AVCaptureDevice.setExposureModeCustom(duration:iso:)`
- Open Camera (开源 Android 相机) 的 manual exposure 实现
- Pocket Light Meter / myLightMeter 算法说明
- 现有：`docs/superpowers/specs/2026-05-23-film-go-design.md` §3.1 测光 Meter

---

*— Spec ends —*
