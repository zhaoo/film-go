# 快速测光 桌面小部件 — 设计

日期：2026-05-25
范围：Android（小米/HyperOS 优先）桌面小部件——一键 ALS 测光
作者：兆兆 + Claude

---

## 1. 目标与范围

在桌面/锁屏放一个 4×2 小部件：点一下「测」按钮，**不打开 App**，~1s 内显示 EV、推荐光圈/快门组合，写回 widget。

**包含**

- 一个标准 Android `AppWidgetProvider`（HyperOS、MIUI、原生桌面、第三方启动器通杀；自动出现在小米的「负一屏」和锁屏 widget 列表）
- 点击 widget 走 `BroadcastReceiver.goAsync()`，协程读 ALS 首帧 → 算 EV / 光圈快门 → 刷新 RemoteViews
- 与 App 共享 ISO 与校准偏移（单向：App → widget，通过 SharedPreferences）
- 三态布局：首次/空、有结果、永久错误（无 ALS）
- 完整 Kotlin 端 ExposureMath 单测（与 Dart 端 fixture 1:1 对照）

**不做**

- iOS WidgetKit（已确认；iOS 系统 API 不允许 widget 进程读 ALS）
- 小米私有「超级小部件」/ App Vault 卡片（标准 AppWidget 已覆盖小米全部桌面位置）
- 2×2 紧凑布局（仅 4×2，若后续要扩另开 spec）
- Widget 上调 ISO（保持极简；要改 ISO 进 App）
- Widget 上展示多组光圈/快门列表（只显示中位数那一对；多组进 App 看）
- 周期性预测光 / `updatePeriodMillis>0`（绝不主动唤醒，是耗电的核心来源）
- Widget 配置 Activity（无配置项）
- 反向同步：widget 测光结果不写回 App 的 `MeterController` 状态（widget 是历史快照，App 是实时；混在一起反而困惑）

---

## 2. 架构总览

```
┌──────────────────── Flutter (Dart) ────────────────────┐
│  MeterController ──[ISO/校准变更]──► WidgetBridge       │
│                                          │              │
└──────────────────────────────────────────┼──────────────┘
                                           │ writes
                                           ▼
                              ┌──────────────────────┐
                              │  SharedPreferences   │  ← 唯一跨进程通道
                              │  (Android default)   │
                              │  - widget.iso        │
                              │  - widget.calOffset  │
                              │  - widget.lastEv     │
                              │  - widget.lastAp     │
                              │  - widget.lastShut   │
                              │  - widget.lastTakenAt│
                              │  - widget.lastError  │
                              │  - widget.loadingAt  │
                              └──────────▲───────────┘
                                         │ reads/writes
┌────────────────────── Android (Kotlin) ┴──────────────────────┐
│                                                                │
│  QuickMeterWidgetProvider : AppWidgetProvider                  │
│    onUpdate / onAppWidgetOptionsChanged → renderRemoteViews()  │
│    onReceive(ACTION_MEASURE) → goAsync() + measure()           │
│                                                                │
│  AlsMeter (suspend fun measure(timeoutMs=1500)): MeterResult   │
│    SensorManager.registerListener(TYPE_LIGHT, FASTEST)         │
│    收第一个 onSensorChanged → unregister → return lux          │
│                                                                │
│  ExposureMath (object)                                         │
│    fromLux(lux, iso, offset) → ev                              │
│    suggestPairs(ev, iso) → ExposurePair?                       │
│    ↑ 复刻自 Dart 端，配套 KotlinTest 跨语言 1:1 fixture 对照   │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### 关键设计决策

1. **不走 Flutter 引擎**：widget 触发的工作完全在 Kotlin 完成，不启动 `FlutterEngine`，避免 200-500ms 冷启 + 30MB 内存开销，对 HyperOS Doze 友好。
2. **不用 Service / Foreground Service**：`BroadcastReceiver.goAsync()` 给 receiver 进程 ~10s 窗口，足够注册 SensorManager + 读首帧（实测 50-200ms）。零通知栏污染。
3. **算法 Kotlin 端复刻一份**：`LuminanceToEv.fromLux` 与 `EvCalculator.suggestPairs` 共约 60 行 Kotlin。trade-off：用「重复 60 行 + 跨语言单测对照」换「零 Flutter 引擎启动」。
4. **SharedPreferences 作为唯一 IPC**：App 端只读改写、widget 端只读，方向清晰。不用 ContentProvider（杀鸡焉用牛刀）。
5. **App → widget 单向同步**：widget 测光只用 widget 本地数据；App 改 ISO 不主动刷新 widget（旧结果保留），下次点测时使用新 ISO。

---

## 3. 文件清单

### Android（Kotlin）新增

| 文件 | 作用 |
|---|---|
| `android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/QuickMeterWidgetProvider.kt` | `AppWidgetProvider` 子类，处理 `onUpdate` 和 `ACTION_MEASURE` |
| `android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/AlsMeter.kt` | `suspend fun measure(ctx, timeoutMs)` 包装 SensorManager |
| `android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/ExposureMath.kt` | `fromLux` + `suggestPairs` + 整档查找表（Aperture/Shutter）|
| `android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/WidgetPrefs.kt` | SharedPreferences key 常量 + 强类型读写 |
| `android/app/src/main/res/xml/quick_meter_widget_info.xml` | `AppWidgetProviderInfo`，`updatePeriodMillis="0"`、`minWidth=180dp`、`minHeight=110dp`、`resizeMode="none"` |
| `android/app/src/main/res/layout/widget_quick_meter.xml` | RemoteViews 主布局（含三态切换） |
| `android/app/src/main/res/drawable/widget_bg.xml` | 圆角黑底（与 App 主题一致）|
| `android/app/src/main/res/values/widget_strings.xml` | widget 用字符串 |

### Android 单测（JVM, JUnit4）

| 文件 | 作用 |
|---|---|
| `android/app/src/test/kotlin/com/zhaoo/filmgo/film_go/widget/ExposureMathTest.kt` | `fromLux` + `suggestPairs` 跨语言 fixture 对照 |
| `android/app/src/test/kotlin/com/zhaoo/filmgo/film_go/widget/WidgetPrefsTest.kt` | read/write round-trip + 默认值 |

> AlsMeter 不写单测（依赖 SensorManager 硬件），改在第 7 节 Manual QA 验。

### Flutter（Dart）新增

| 文件 | 作用 |
|---|---|
| `lib/services/widget_bridge.dart` | 抽象 + Android 实现；监听 `MeterController` 把 ISO/校准写 SharedPreferences |
| `test/services/widget_bridge_test.dart` | 单测：验证状态变更被写入；listener 在 dispose 后取消 |

### Flutter 修改

| 文件 | 改动 |
|---|---|
| `lib/main.dart` | 在 `ProviderScope` 启动后注册 `WidgetBridge` 监听器（条件：Platform.isAndroid）|
| `android/app/src/main/AndroidManifest.xml` | 注册 `<receiver>` + `<meta-data>` + 自定义 action `<intent-filter>` |

不新增任何 runtime permission；`light` 插件已声明 `android.hardware.sensor.light`，SensorManager 不需要 runtime permission。

---

## 4. 数据流

### 4.1 一次测光的时间线

```
T+0ms     用户点击 widget 的"测光"按钮
T+5ms     PendingIntent.getBroadcast 触发
          → QuickMeterWidgetProvider.onReceive(ACTION_MEASURE)
T+10ms    立即用 RemoteViews 切到"测光中…"loading 态，写入 widget.loadingAt = now
          AppWidgetManager.updateAppWidget()
          goAsync() 拿 PendingResult（系统给 10s 窗口）
T+15ms    协程内（Dispatchers.Default）
          AtomicBoolean inFlight 守护：若已 in-flight，直接 finish() 退出
          SensorManager.registerListener(TYPE_LIGHT, SENSOR_DELAY_FASTEST)
          withTimeout(1500ms) suspend 等首个 onSensorChanged
T+~150ms  收到首个 lux（典型 50-200ms）
          unregister
T+155ms   WidgetPrefs.read() → iso, calibrationOffset
T+158ms   ev = ExposureMath.fromLux(lux, iso, calibrationOffset)
          pairs = ExposureMath.suggestPairs(ev, iso)
          若 pairs 非空：pair = pairs[pairs.size / 2]（中位数）
          若 pairs 为空：lastError = OUT_OF_RANGE，保留旧的 lastAperture/lastShutter
T+160ms   WidgetPrefs.write {
            lastEv, lastAperture (新或旧), lastShutter (新或旧),
            lastTakenAt = now,
            lastError = null 或 OUT_OF_RANGE,
            loadingAt = 0,  ← 任何路径退出都清 0
          }
T+165ms   renderRemoteViews() + AppWidgetManager.updateAppWidget
T+170ms   PendingResult.finish() —— receiver 进程可被系统回收

任何异常路径（NO_SENSOR / TIMEOUT / OUT_OF_RANGE）都必须：
  - 设置 lastError = 对应 code
  - 设置 loadingAt = 0
  - 不覆盖 lastEv / lastAperture / lastShutter / lastTakenAt（保留旧结果）
  - 仍要走 renderRemoteViews + finish
```

### 4.2 App → widget 单向同步

```
用户在 App 改 ISO          →  MeterController.setIso
                            →  WidgetBridge listener
                            →  SharedPreferences.setInt("widget.iso", v)
                            （不调用 AppWidgetManager.updateAppWidget；
                             也不修改 widget.lastEv/Ap/Shut）

用户在 App 完成校准         →  MeterController.applyCalibrationFromLastReading
                            →  WidgetBridge listener
                            →  SharedPreferences.setDouble("widget.calOffset", v)
                            （同样不主动刷新 widget）
```

### 4.3 SharedPreferences schema

```kotlin
object WidgetPrefs {
    private const val PREFS = "FlutterSharedPreferences"  // 与 shared_preferences 插件默认 namespace 一致
    private const val PREFIX = "flutter."                  // shared_preferences 插件加的前缀

    const val KEY_ISO            = "${PREFIX}widget.iso"
    const val KEY_CAL_OFFSET     = "${PREFIX}widget.calOffset"
    const val KEY_LAST_EV        = "${PREFIX}widget.lastEv"
    const val KEY_LAST_APERTURE  = "${PREFIX}widget.lastAperture"   // f-number, double
    const val KEY_LAST_SHUTTER   = "${PREFIX}widget.lastShutter"    // seconds, double
    const val KEY_LAST_TAKEN_AT  = "${PREFIX}widget.lastTakenAt"    // millis since epoch
    const val KEY_LAST_ERROR     = "${PREFIX}widget.lastError"      // String code or null
    const val KEY_LOADING_AT     = "${PREFIX}widget.loadingAt"      // millis since epoch or 0
}
```

⚠️ **待人工验证**（spec 编写时无法上网）：Flutter `shared_preferences` 插件在 Android 上的实际存储位置与 key 前缀，需在动工前实测确认。当前假设是默认 `FlutterSharedPreferences` 文件 + `flutter.` 前缀（基于插件 README 历史版本知识）。若不符，调整 `WidgetPrefs` 常量即可，不影响整体架构。

---

## 5. Widget 三态布局（4×2）

```
┌─────────────────────────┐    ┌─────────────────────────┐    ┌─────────────────────────┐
│  Film·Go               │    │  Film·Go               │    │  Film·Go        ⚠       │
│                        │    │                        │    │                        │
│   按下方按钮测光         │    │   EV 12.3              │    │   测光失败              │
│                        │    │   f/8 · 1/250 · ISO400 │    │   设备无环境光传感器     │
│                        │    │   18:42 测              │    │                        │
│      ┌──────────┐      │    │      ┌──────────┐      │    │      ┌──────────┐      │
│      │   测     │      │    │      │   再测   │      │    │      │   打开App │      │
│      └──────────┘      │    │      └──────────┘      │    │      └──────────┘      │
└─────────────────────────┘    └─────────────────────────┘    └─────────────────────────┘
        首次/空状态                    已有结果                      永久错误回退
```

### 状态判定（在 `renderRemoteViews`）

```
val now = System.currentTimeMillis()
val loadingAt = prefs.getLong(KEY_LOADING_AT, 0L)
val loading = loadingAt > 0 && (now - loadingAt) < 2000  // loading 兜底：超过 2s 自动失效
val error   = prefs.getString(KEY_LAST_ERROR, null)
val taken   = prefs.getLong(KEY_LAST_TAKEN_AT, 0L)

state = when {
    loading                            -> Loading
    error == "NO_SENSOR"               -> PermanentError
    error == "TIMEOUT"  && taken == 0L -> EmptyWithLastError("测光超时，再试一次")
    error == "TIMEOUT"  && taken > 0L  -> ResultWithFootnote("上次超时，再试一次")
    error == "OUT_OF_RANGE"            -> Result（第二行改为「超出快门范围」）
    taken > 0L                         -> Result
    else                               -> Empty
}
```

⚠️ Result/ResultWithFootnote/Result-with-out-of-range 三个变体共用同一份 RemoteViews layout，只切换文案与一个 `footnote` TextView 的 visibility。

### RemoteViews 受限说明
- 只能用 `TextView` / `ImageView` / `Button` / `LinearLayout` / `FrameLayout` / `RelativeLayout` / `GridLayout` 等白名单 View
- 不能用 `ConstraintLayout`、`RecyclerView`（除非用 `RemoteViewsService.RemoteViewsFactory`）
- 三态切换通过 `setViewVisibility(View.VISIBLE/GONE)` 在同一份 layout 内做，不是切换 layout 文件

---

## 6. 错误处理矩阵

| 失败场景 | 检测点 | Widget 行为 | `lastError` 写入 |
|---|---|---|---|
| 设备无 ALS（`getDefaultSensor(TYPE_LIGHT) == null`）| `AlsMeter.measure()` 开头 | 永久错误布局，按钮变「打开 App」（指向 Pro 测光相机模式）| `NO_SENSOR` |
| 1500ms 未收到 `onSensorChanged`（`withTimeout` 抛 `TimeoutCancellationException`）| `AlsMeter.measure()` | 提示「测光超时，再试一次」；保留 `lastEv/Ap/Shut` 不覆盖 | `TIMEOUT` |
| `goAsync` 在 10s 系统窗口内被杀（HyperOS 极端情况）| 无法直接检测 | `renderRemoteViews` 检查 `loadingAt` 与 `lastTakenAt`：若 loadingAt 比 lastTakenAt 旧且超过 2s，自动退回 Result 或 Empty 态 | 无 |
| `ExposureMath.suggestPairs` 返回空（EV 落在所有光圈/快门组合 0.5 stop 容差外）| 主流程 | 仍显示 EV，第二行换成「超出快门范围」 | `OUT_OF_RANGE` |
| `lux=0`（完全黑）| AlsMeter 收到值后 | `_luxFloor=0.01` 兜底（与 Dart `LuminanceToEv._luxFloor` 一致），照常算 | 无 |
| Widget 进程读 SharedPreferences 无值（App 从未启动过）| `WidgetPrefs.read` 返回默认 | 用 `iso=400`、`offset=0` 兜底测光；结果粗略但可用 | 无 |
| 二次点击（测光中又按）| `onReceive` | `AtomicBoolean inFlight` 守护，二次点击直接 `finish()` 退出，不取消进行中的 | 无 |
| Widget 添加到桌面后 App 未启动直接点测 | 同「无值」场景 | 同上 | 无 |

---

## 7. 测试策略

### 7.1 Dart 单测

`test/services/widget_bridge_test.dart`：
- mock `SharedPreferences`，验证：
  - `MeterController.setIso(800)` 后，prefs 里 `widget.iso == 800`
  - `applyCalibrationFromLastReading` 后，`widget.calOffset` 与 controller 一致
  - 监听器在 `MeterController.dispose()` 后被解绑（写入次数不再增加）
- 现有 `ev_calculator_test.dart` / `luminance_to_ev_test.dart` 不动

### 7.2 Kotlin 单测（JVM, JUnit4）

`ExposureMathTest.kt`：
- 从 `luminance_to_ev_test.dart` 的 `fromLux` 测试用例摘 5-8 个 `[lux, iso, offset, expectedEv]` fixture，硬编码进 Kotlin 端做 1:1 对照（要求误差 < 1e-6）
- 从 `ev_calculator_test.dart` 的 `suggestPairs` 用例摘 5-8 个 `[ev, iso, expectedAperture, expectedShutter]` fixture，验证中位数选择稳定
- 边界 case：`lux=0`、`lux=1e6`、`iso=50`、`iso=51200`、`ev` 极端值

`WidgetPrefsTest.kt`：
- read/write round-trip 各字段
- 缺 key 时返回的默认值正确（`iso=400`、`offset=0.0`、`lastError=null`、`taken=0L`）

### 7.3 端到端 Manual QA Checklist（M0 release 前必跑）

1. **冷启 widget**：全新安装、未打开 App，桌面长按 → 加 widget → 按测光 → 用 `iso=400` 测出粗值，无崩溃
2. **ISO 同步**：打开 App → ISO 改为 800 → 做一次校准 → 回桌面按 widget → 数值反映 ISO=800 + 新 offset
3. **HyperOS 锁屏存活**：在小米 14（HyperOS 2.0）测一次 → 锁屏 10 分钟 → 解锁桌面再测一次 → 仍能 1.5s 内出值
4. **零唤醒**：`adb shell dumpsys batterystats --reset` → widget 静置 1 小时（不点击）→ 检查 widget 自身贡献的 wake 次数 == 0
5. **无传感器降级**：旧机型或模拟器（无 ALS）→ 应显示「无传感器」永久错误态，按钮跳 App
6. **明暗极端值**：手电筒直射 → 正常出 EV 不崩；完全遮黑 → 正常出 EV（典型 < 0 EV）不崩
7. **二次点击**：测光 loading 期间快速再按一次 → 不崩、不重复测、不重叠通知
8. **多 widget 实例**：桌面挂两个 widget → 同时点 → 两个都正常出值
9. **小米桌面 ↔ 第三方启动器（Nova）**：两边都能加、能用

### 7.4 性能预算（验证标准）

- 点击 → 出值：P50 < 800ms、P99 < 1500ms（手动 QA 第 1/2/3 项里掐表）
- 待机 24h 期间，widget 自身贡献：0 次 CPU wake、0 个 service started、< 1KB SharedPreferences 写入（QA 第 4 项）

---

## 8. 实现顺序（PR 切分建议，留给 writing-plans 细化）

1. **PR1：Dart WidgetBridge + 单测**（无 Android 改动，只是把 ISO/校准写到 SharedPreferences；可独立合并）
2. **PR2：Kotlin ExposureMath + WidgetPrefs + 单测**（无 widget UI；纯算法和存储）
3. **PR3：AlsMeter + QuickMeterWidgetProvider + RemoteViews 布局 + Manifest 注册**（接入 widget，能跑通端到端）
4. **PR4：三态布局精修 + Manual QA 跑通**（视觉打磨与极端 case 兜底）

---

## 9. 风险与待人工验证

| 项 | 风险 | 应对 |
|---|---|---|
| `shared_preferences` 插件实际存储 key 前缀 | 假设 `flutter.` 前缀，若插件版本变更可能不符 | PR1 实测确认；不符则调整 `WidgetPrefs` 常量 |
| HyperOS 对 `BroadcastReceiver.goAsync` 10s 窗口的实际遵守 | 极端省电模式下可能 < 10s 就被杀 | 已有 `loadingAt` 自动退回机制兜底 |
| ALS 首帧延迟在低端机上 > 1500ms | 触发 TIMEOUT，体验降级 | 1500ms 已经是相当宽裕的预算，若实测频繁触发可调到 2500ms |
| 小米 14 / HyperOS 桌面对自定义 widget 圆角的渲染 | 视觉可能与设计稿不一致 | PR4 视觉调整阶段处理 |
| 小米私有「超级小部件」入口需求 | 用户后续可能想挂上去 | 本期不做；标准 AppWidget 在小米桌面与负一屏均可挂载，已覆盖主要场景 |

---

## 10. 后续可能性（不在本期）

- iOS WidgetKit「打开 App 测光」入口（降级方案）
- 2×2 紧凑布局
- 多组光圈/快门一键切换
- 桌面长按 widget 弹出「重置 ISO」等配置 Activity
- 小米超级小部件适配（需要小米开发者审核）
- 主页面 App 内的「最近 widget 测光」历史
