# 快速测光 桌面小部件 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Android 桌面小部件「快速测光」：点击 → 不打开 App → ~1s 内读 ALS 给出 EV + 推荐光圈/快门。

**Architecture:** 标准 `AppWidgetProvider` + `BroadcastReceiver.goAsync()` 协程 + Kotlin 复刻 ExposureMath。SharedPreferences 作为 App↔widget 唯一 IPC（单向 App→widget 同步 ISO/校准）。不启动 FlutterEngine、不用 Service、不周期唤醒。

**Tech Stack:** Kotlin（widget 端）、Dart/Flutter（App 端）、`shared_preferences` Flutter 插件、Android SensorManager、JUnit4（Kotlin 单测）、flutter_test+mocktail（Dart 单测）。

**Spec:** `docs/superpowers/specs/2026-05-25-quick-meter-widget-design.md`

---

## PR 切分

| PR | 范围 | 可独立合并 |
|---|---|---|
| PR1 | Dart `WidgetBridge` + 单测 + main.dart 接入 | ✅（无 Android 改动） |
| PR2 | Kotlin `ExposureMath` + `WidgetPrefs` + 单测 | ✅（无 UI） |
| PR3 | `AlsMeter` + `QuickMeterWidgetProvider` + RemoteViews + Manifest | ⚠️ 依赖 PR1+PR2 |
| PR4 | 视觉打磨 + 跑通 Manual QA | ⚠️ 依赖 PR3 |

---

# PR1 — Dart WidgetBridge

## Task 1.1：已验证 — shared_preferences_android 2.4.7 存储格式

**已查实**（直接读 `~/.pub-cache/hosted/pub.flutter-io.cn/shared_preferences_android-2.4.7/android/src/main/kotlin/io/flutter/plugins/sharedpreferences/SharedPreferencesPlugin.kt` + `shared_preferences-2.5.3/lib/src/shared_preferences_legacy.dart`）：

| 维度 | 实际值 |
|---|---|
| 文件 | `PreferenceManager.getDefaultSharedPreferences(context)` → **`{packageName}_preferences.xml`**（不是 `FlutterSharedPreferences`） |
| Key 前缀 | `flutter.`（`shared_preferences_legacy.dart:22`） |
| `setInt` 编码 | `putLong(key, value.toLong())` → Long |
| `setDouble` 编码 | `putString(key, DOUBLE_PREFIX + value)` → **String**，其中 `DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"`（base64 of `"This is the prefix for Double."`） |
| `setBool` 编码 | `putBoolean(key, value)` → Boolean |
| `setString` 编码 | `putString(key, value)` → String |

**结论：** Kotlin 端读 Dart `double` 必须按 String 读 + 去前缀 + `toDouble()`。读 Dart `int` 按 Long 读。这与本 plan 草稿原假设（float / long-bits 双路径）完全不同——Task 2.5 已按真实编码改正。

不需要 commit，进入 Task 1.2。

---

## Task 1.2：写 `WidgetBridge` 失败测试

**Files:**
- Create: `test/services/widget_bridge_test.dart`

- [ ] **Step 1：写测试文件**

```dart
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/widget_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStore implements CalibrationStoreLike {
  double _v = 0;
  @override
  double read() => _v;
  @override
  Future<void> write(double offset) async => _v = offset;
  @override
  Future<void> clear() async => _v = 0;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetBridge', () {
    test('attach 后立即写入当前 ISO 与校准', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = MeterController(store: _FakeStore())..bootstrap();
      final bridge = WidgetBridge(prefs: prefs);

      bridge.attach(controller);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getInt('widget.iso'), 400);
      expect(prefs.getDouble('widget.calOffset'), 0.0);
    });

    test('setIso 后 SharedPreferences 同步更新', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = MeterController(store: _FakeStore())..bootstrap();
      WidgetBridge(prefs: prefs).attach(controller);
      await Future<void>.delayed(Duration.zero);

      controller.setIso(IsoValue(800));
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getInt('widget.iso'), 800);
    });

    test('detach 后停止写入', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = MeterController(store: _FakeStore())..bootstrap();
      final bridge = WidgetBridge(prefs: prefs);
      bridge.attach(controller);
      await Future<void>.delayed(Duration.zero);

      bridge.detach();
      controller.setIso(IsoValue(1600));
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getInt('widget.iso'), 400, reason: '已 detach 不应再写');
    });
  });
}
```

- [ ] **Step 2：跑测试确认 fail**

Run: `flutter test test/services/widget_bridge_test.dart`
Expected: FAIL，错误信息是 `Target of URI doesn't exist: 'package:film_go/services/widget_bridge.dart'`。

---

## Task 1.3：实现 `WidgetBridge`

**Files:**
- Create: `lib/services/widget_bridge.dart`

- [ ] **Step 1：写最小实现**

```dart
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 把 MeterController 的 ISO / 校准变化单向同步到 SharedPreferences，
/// 供桌面小部件（Android）读取。Widget 端不通过 FlutterEngine，因此用
/// SharedPreferences 作为唯一跨进程通道。
class WidgetBridge {
  WidgetBridge({required this.prefs});

  final SharedPreferences prefs;

  static const keyIso = 'widget.iso';
  static const keyCalOffset = 'widget.calOffset';

  MeterController? _controller;
  late void Function() _listener;

  void attach(MeterController controller) {
    _controller = controller;
    _listener = () => _sync(controller);
    controller.addListener(_listener);
    _sync(controller);
  }

  void detach() {
    _controller?.removeListener(_listener);
    _controller = null;
  }

  int _lastIso = -1;
  double _lastOffset = double.nan;

  void _sync(MeterController c) {
    final iso = c.state.shared.iso.value;
    final off = c.state.shared.calibrationOffset;
    if (iso != _lastIso) {
      prefs.setInt(keyIso, iso);
      _lastIso = iso;
    }
    if (off != _lastOffset) {
      prefs.setDouble(keyCalOffset, off);
      _lastOffset = off;
    }
  }
}
```

- [ ] **Step 2：跑测试**

Run: `flutter test test/services/widget_bridge_test.dart`
Expected: 全部 3 个 test PASS。

- [ ] **Step 3：commit**

```bash
git add lib/services/widget_bridge.dart test/services/widget_bridge_test.dart
git commit -m "feat(widget): add WidgetBridge to mirror ISO/calibration to SharedPreferences

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 1.4：在 `main.dart` 接入 `WidgetBridge`

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1：替换 `main` 函数**

把 `main.dart` 现有 `main()` 替换为：

```dart
import 'dart:io';

import 'package:film_go/app.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/widget_bridge.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await CalibrationStore.create();
  final controller = MeterController(store: store)..bootstrap();

  if (Platform.isAndroid) {
    final prefs = await SharedPreferences.getInstance();
    WidgetBridge(prefs: prefs).attach(controller);
  }

  runApp(
    ProviderScope(
      overrides: [
        meterControllerProvider.overrideWith((ref) => controller),
      ],
      child: const FilmGoApp(),
    ),
  );
}
```

- [ ] **Step 2：跑整套测试**

Run: `flutter test`
Expected: 全套 PASS。注意现有 `widget_test.dart`（如果存在）可能依赖默认 `ProviderScope`，若 fail 检查它是否用了 `meterControllerProvider`；通常 smoke test 不会 fail。

- [ ] **Step 3：commit**

```bash
git add lib/main.dart
git commit -m "feat(widget): wire WidgetBridge into main bootstrap

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

# PR2 — Kotlin ExposureMath + WidgetPrefs（+ 单测）

## Task 2.1：在 app gradle 加 JUnit 测试依赖

**Files:**
- Modify: `android/app/build.gradle`

- [ ] **Step 1：在 `android { ... }` 闭合之前插入 `testOptions`，并在文件末尾追加 `dependencies` 块**

把 `android/app/build.gradle` 末尾的 `flutter { source = "../.." }` 之前插入：

```gradle
    testOptions {
        unitTests {
            includeAndroidResources = false
            returnDefaultValues = true
        }
    }
```

并在 `flutter { ... }` 之后追加：

```gradle
dependencies {
    testImplementation "junit:junit:4.13.2"
    testImplementation "org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3"
}
```

- [ ] **Step 2：确认 gradle 同步通过**

Run: `cd android && ./gradlew :app:dependencies --configuration testRuntimeClasspath 2>&1 | tail -20`
Expected: 列表里能看到 `junit-4.13.2.jar` 与 `kotlinx-coroutines-test-1.7.3`。

- [ ] **Step 3：commit**

```bash
git add android/app/build.gradle
git commit -m "build(android): add JUnit + coroutines-test for widget unit tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2.2：写 `ExposureMath.fromLux` 失败测试

**Files:**
- Create: `android/app/src/test/kotlin/com/zhaoo/filmgo/film_go/widget/ExposureMathTest.kt`

- [ ] **Step 1：写测试**

```kotlin
package com.zhaoo.filmgo.film_go.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import kotlin.math.abs

class ExposureMathTest {

    private fun assertClose(expected: Double, actual: Double, eps: Double = 1e-6) {
        assert(abs(expected - actual) < eps) { "expected $expected ± $eps, got $actual" }
    }

    // 与 Dart luminance_to_ev_test.dart 同 fixture：lux=2.5, ISO 100, offset 0 → EV 0
    @Test fun `fromLux 2_5 lux ISO100 offset0 returns 0`() {
        val ev = ExposureMath.fromLux(lux = 2.5, iso = 100, calibrationOffset = 0.0)
        assertClose(0.0, ev)
    }

    @Test fun `fromLux doubling lux equals plus one EV`() {
        val dim = ExposureMath.fromLux(lux = 100.0, iso = 100, calibrationOffset = 0.0)
        val bright = ExposureMath.fromLux(lux = 200.0, iso = 100, calibrationOffset = 0.0)
        assertClose(1.0, bright - dim, 1e-9)
    }

    @Test fun `fromLux doubling iso equals plus one EV`() {
        val at100 = ExposureMath.fromLux(lux = 100.0, iso = 100, calibrationOffset = 0.0)
        val at200 = ExposureMath.fromLux(lux = 100.0, iso = 200, calibrationOffset = 0.0)
        assertClose(1.0, at200 - at100, 1e-9)
    }

    @Test fun `fromLux calibration offset added directly`() {
        val base = ExposureMath.fromLux(lux = 100.0, iso = 100, calibrationOffset = 0.0)
        val tuned = ExposureMath.fromLux(lux = 100.0, iso = 100, calibrationOffset = 1.5)
        assertClose(1.5, tuned - base, 1e-9)
    }

    @Test fun `fromLux zero lux returns finite low value`() {
        val ev = ExposureMath.fromLux(lux = 0.0, iso = 100, calibrationOffset = 0.0)
        assert(ev.isFinite())
        assert(ev < -5) { "完全黑应返回非常低 EV，得到 $ev" }
    }

    @Test fun `suggestPairs at EV15 ISO100 contains Sunny16-ish pair`() {
        val pairs = ExposureMath.suggestPairs(ev = 15.0, iso = 100)
        // f/16 → 1/125 附近
        val hit = pairs.any { it.apertureFNumber == 16.0 && abs(it.shutterSeconds - 1.0 / 125.0) < 1.0 / 80.0 }
        assert(hit) { "expected f/16 ~1/125 in $pairs" }
    }

    @Test fun `suggestPairs sorted by aperture ascending`() {
        val pairs = ExposureMath.suggestPairs(ev = 13.0, iso = 100)
        assert(pairs.size >= 2)
        for (i in 1 until pairs.size) {
            assert(pairs[i].apertureFNumber > pairs[i - 1].apertureFNumber)
        }
    }

    @Test fun `suggestPairs at EV0 ISO100 includes f1 1s and excludes f64`() {
        val pairs = ExposureMath.suggestPairs(ev = 0.0, iso = 100)
        assert(pairs.any { it.apertureFNumber == 1.0 })
        assert(pairs.none { it.apertureFNumber == 64.0 })
    }

    @Test fun `suggestPairs at extreme EV returns empty`() {
        val pairs = ExposureMath.suggestPairs(ev = 30.0, iso = 100)
        assert(pairs.isEmpty()) { "EV 30 应超过所有快门快端 0.5 stop 容差" }
    }

    @Test fun `median picks middle pair`() {
        val pairs = listOf(
            ExposurePair(2.0, 1.0 / 30.0),
            ExposurePair(4.0, 1.0 / 60.0),
            ExposurePair(8.0, 1.0 / 125.0),
            ExposurePair(11.0, 1.0 / 250.0),
            ExposurePair(16.0, 1.0 / 500.0),
        )
        // 中位数：5 ~/ 2 = 2 → 第 3 个 (index 2)
        val pick = ExposureMath.medianOrNull(pairs)
        assertNotNull(pick)
        assertEquals(8.0, pick!!.apertureFNumber, 1e-9)
    }

    @Test fun `median of empty returns null`() {
        assertNull(ExposureMath.medianOrNull(emptyList()))
    }
}
```

- [ ] **Step 2：跑测试确认 fail**

Run:
```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "com.zhaoo.filmgo.film_go.widget.ExposureMathTest"
```
Expected: 编译失败，提示 `unresolved reference: ExposureMath` / `ExposurePair`。

---

## Task 2.3：实现 `ExposureMath` 与 `ExposurePair`

**Files:**
- Create: `android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/ExposureMath.kt`

- [ ] **Step 1：写实现**

```kotlin
package com.zhaoo.filmgo.film_go.widget

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.pow

/** 一组曝光参数：光圈 f-number + 快门秒数。 */
data class ExposurePair(val apertureFNumber: Double, val shutterSeconds: Double)

/**
 * Widget 端的 ExposureMath，与 Dart 端 `LuminanceToEv.fromLux` /
 * `EvCalculator.suggestPairs` 同公式同 fixture。
 *
 * 不复用 Dart 实现的原因：widget 进程不启动 FlutterEngine。重复约 60 行
 * 换零冷启延迟和 30MB 内存（详见 spec 第 2 节决策 3）。
 */
object ExposureMath {

    /** 入射光测光常数 C = 2.5（CIPA / ISO 2720），与 Dart 端一致。 */
    private const val C_INCIDENT = 2.5

    /** lux 下界，防 log2(0) = -∞。与 Dart `_luxFloor` 一致。 */
    private const val LUX_FLOOR = 0.01

    /** suggestPairs 的最大 stop 容差，与 Dart 端 `tolerance` 一致。 */
    private const val SHUTTER_TOLERANCE_STOPS = 0.5

    /** 标准整档光圈，与 Dart `Aperture.fullStops` 一致（13 档）。 */
    val APERTURES_FULL_STOPS: List<Double> = listOf(
        1.0,
        1.4142135623730951,   // √2
        2.0,
        2.8284271247461903,   // 2√2
        4.0,
        5.656854249492381,    // 4√2
        8.0,
        11.313708498984761,   // 8√2
        16.0,
        22.627416997969522,   // 16√2
        32.0,
        45.254833995939045,   // 32√2
        64.0,
    )

    /** 标准整档快门秒数，与 Dart `ShutterSpeed.fullStops` 一致（19 档）。 */
    val SHUTTERS_FULL_STOPS_SECONDS: List<Double> = listOf(
        30.0, 15.0, 8.0, 4.0, 2.0, 1.0,
        1.0 / 2.0, 1.0 / 4.0, 1.0 / 8.0, 1.0 / 15.0,
        1.0 / 30.0, 1.0 / 60.0, 1.0 / 125.0, 1.0 / 250.0,
        1.0 / 500.0, 1.0 / 1000.0, 1.0 / 2000.0, 1.0 / 4000.0, 1.0 / 8000.0,
    )

    /** EV(入射) = log2(lux / C) + log2(ISO/100) + offset。 */
    fun fromLux(lux: Double, iso: Int, calibrationOffset: Double): Double {
        val l = if (lux < LUX_FLOOR) LUX_FLOOR else lux
        val base = ln(l / C_INCIDENT) / ln(2.0)
        val isoTerm = ln(iso / 100.0) / ln(2.0)
        return base + isoTerm + calibrationOffset
    }

    /**
     * 给定 EV/ISO，遍历整档光圈给出对应快门组合（最接近整档），
     * 距离 > 0.5 stop 的丢弃。结果按光圈递增。
     */
    fun suggestPairs(ev: Double, iso: Int): List<ExposurePair> {
        val isoTerm = ln(iso / 100.0) / ln(2.0)
        val ev100 = ev - isoTerm
        val out = ArrayList<ExposurePair>(APERTURES_FULL_STOPS.size)
        for (n in APERTURES_FULL_STOPS) {
            val theory = (n * n) / 2.0.pow(ev100)
            if (theory <= 0 || theory.isInfinite() || theory.isNaN()) continue
            val snapped = snapShutter(theory) ?: continue
            val dist = abs(ln(theory / snapped) / ln(2.0))
            if (dist > SHUTTER_TOLERANCE_STOPS) continue
            out.add(ExposurePair(apertureFNumber = n, shutterSeconds = snapped))
        }
        return out
    }

    /** 取 pairs 的中位数（pairs.size / 2），空列表返回 null。 */
    fun medianOrNull(pairs: List<ExposurePair>): ExposurePair? =
        if (pairs.isEmpty()) null else pairs[pairs.size / 2]

    private fun snapShutter(targetSec: Double): Double? {
        var best: Double? = null
        var bestDist = Double.MAX_VALUE
        for (s in SHUTTERS_FULL_STOPS_SECONDS) {
            val d = abs(ln(targetSec / s) / ln(2.0))
            if (d < bestDist) {
                bestDist = d
                best = s
            }
        }
        return best
    }
}
```

- [ ] **Step 2：跑测试**

Run:
```bash
cd android && ./gradlew :app:testDebugUnitTest --tests "com.zhaoo.filmgo.film_go.widget.ExposureMathTest"
```
Expected: 全部 11 个 test PASS。

- [ ] **Step 3：commit**

```bash
git add android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/ExposureMath.kt \
        android/app/src/test/kotlin/com/zhaoo/filmgo/film_go/widget/ExposureMathTest.kt
git commit -m "feat(widget): port LuminanceToEv.fromLux + EvCalculator.suggestPairs to Kotlin

跨语言 fixture 1:1 对照 (误差 < 1e-6)，避免 widget 进程启动 FlutterEngine。

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2.4：写 `WidgetPrefs` 失败测试

**Files:**
- Create: `android/app/src/test/kotlin/com/zhaoo/filmgo/film_go/widget/WidgetPrefsTest.kt`

- [ ] **Step 1：写测试**

```kotlin
package com.zhaoo.filmgo.film_go.widget

import org.junit.Test
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull

class WidgetPrefsTest {

    /** 内存版 SharedPreferences，避免起 Android 上下文。 */
    private class FakePrefs : android.content.SharedPreferences {
        val data = HashMap<String, Any?>()
        override fun getAll(): MutableMap<String, *> = data
        override fun getString(key: String, defValue: String?) = data[key] as String? ?: defValue
        override fun getStringSet(key: String, defValues: MutableSet<String>?) = defValues
        override fun getInt(key: String, defValue: Int) = (data[key] as? Long)?.toInt() ?: (data[key] as? Int) ?: defValue
        override fun getLong(key: String, defValue: Long) = (data[key] as? Long) ?: defValue
        override fun getFloat(key: String, defValue: Float) = (data[key] as? Float) ?: defValue
        override fun getBoolean(key: String, defValue: Boolean) = (data[key] as? Boolean) ?: defValue
        override fun contains(key: String) = data.containsKey(key)
        override fun edit(): android.content.SharedPreferences.Editor = FakeEditor(this)
        override fun registerOnSharedPreferenceChangeListener(l: android.content.SharedPreferences.OnSharedPreferenceChangeListener?) {}
        override fun unregisterOnSharedPreferenceChangeListener(l: android.content.SharedPreferences.OnSharedPreferenceChangeListener?) {}
    }

    private class FakeEditor(val prefs: FakePrefs) : android.content.SharedPreferences.Editor {
        override fun putString(key: String, value: String?) = apply { prefs.data[key] = value }
        override fun putStringSet(key: String, values: MutableSet<String>?) = this
        override fun putInt(key: String, value: Int) = apply { prefs.data[key] = value }
        override fun putLong(key: String, value: Long) = apply { prefs.data[key] = value }
        override fun putFloat(key: String, value: Float) = apply { prefs.data[key] = value }
        override fun putBoolean(key: String, value: Boolean) = apply { prefs.data[key] = value }
        override fun remove(key: String) = apply { prefs.data.remove(key) }
        override fun clear() = apply { prefs.data.clear() }
        override fun commit() = true
        override fun apply() {}
    }

    @Test fun `default iso is 400 when missing`() {
        val p = WidgetPrefs(FakePrefs())
        assertEquals(400, p.iso)
    }

    @Test fun `default calibration offset is 0`() {
        val p = WidgetPrefs(FakePrefs())
        assertEquals(0.0, p.calibrationOffset, 1e-9)
    }

    @Test fun `lastError defaults to null`() {
        val p = WidgetPrefs(FakePrefs())
        assertNull(p.lastError)
    }

    @Test fun `lastTakenAt defaults to 0`() {
        val p = WidgetPrefs(FakePrefs())
        assertEquals(0L, p.lastTakenAt)
    }

    @Test fun `writeResult round-trips ev aperture shutter taken`() {
        val raw = FakePrefs()
        val p = WidgetPrefs(raw)
        p.writeResult(ev = 12.3, apertureFNumber = 8.0, shutterSeconds = 1.0 / 250.0, takenAtMillis = 1234567890L)
        assertEquals(12.3, p.lastEv!!, 1e-9)
        assertEquals(8.0, p.lastApertureFNumber!!, 1e-9)
        assertEquals(1.0 / 250.0, p.lastShutterSeconds!!, 1e-9)
        assertEquals(1234567890L, p.lastTakenAt)
        assertNull(p.lastError)
    }

    @Test fun `reads Dart-encoded double (DOUBLE_PREFIX + value as String)`() {
        val raw = FakePrefs()
        // 模拟 Dart shared_preferences 写入的真实格式
        raw.data[WidgetPrefs.KEY_CAL_OFFSET] = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu" + "0.42"
        val p = WidgetPrefs(raw)
        assertEquals(0.42, p.calibrationOffset, 1e-9)
    }

    @Test fun `reads Dart-encoded int (Long)`() {
        val raw = FakePrefs()
        raw.data[WidgetPrefs.KEY_ISO] = 800L
        val p = WidgetPrefs(raw)
        assertEquals(800, p.iso)
    }

    @Test fun `writeError sets error code and clears loading`() {
        val p = WidgetPrefs(FakePrefs())
        p.markLoading()
        assert(p.loadingAt > 0)
        p.writeError("TIMEOUT")
        assertEquals("TIMEOUT", p.lastError)
        assertEquals(0L, p.loadingAt)
    }
}
```

- [ ] **Step 2：跑测试确认 fail**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.zhaoo.filmgo.film_go.widget.WidgetPrefsTest"`
Expected: 编译失败，`unresolved reference: WidgetPrefs`。

---

## Task 2.5：实现 `WidgetPrefs`

**Files:**
- Create: `android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/WidgetPrefs.kt`

- [ ] **Step 1：写实现**

```kotlin
package com.zhaoo.filmgo.film_go.widget

import android.content.Context
import android.content.SharedPreferences
import android.preference.PreferenceManager

/**
 * SharedPreferences 强类型读写 wrapper。
 *
 * 与 Flutter `shared_preferences` 插件 2.4.7（legacy sync API）保持一致：
 *   - file:   PreferenceManager.getDefaultSharedPreferences()
 *             → `{packageName}_preferences.xml`
 *   - prefix: "flutter."
 *   - int    → Long
 *   - double → String，前缀 DOUBLE_PREFIX + value.toString()
 *
 * 详见 Task 1.1 实测确认。
 */
class WidgetPrefs(private val prefs: SharedPreferences) {

    companion object {
        private const val P = "flutter."

        /** shared_preferences_android 2.x 用此前缀把 String 标记为 Dart double。 */
        const val DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

        const val KEY_ISO            = "${P}widget.iso"
        const val KEY_CAL_OFFSET     = "${P}widget.calOffset"
        const val KEY_LAST_EV        = "${P}widget.lastEv"
        const val KEY_LAST_APERTURE  = "${P}widget.lastAperture"
        const val KEY_LAST_SHUTTER   = "${P}widget.lastShutter"
        const val KEY_LAST_TAKEN_AT  = "${P}widget.lastTakenAt"
        const val KEY_LAST_ERROR     = "${P}widget.lastError"
        const val KEY_LOADING_AT     = "${P}widget.loadingAt"

        @Suppress("DEPRECATION")
        fun from(context: Context): WidgetPrefs =
            WidgetPrefs(PreferenceManager.getDefaultSharedPreferences(context))
    }

    val iso: Int get() = prefs.getLong(KEY_ISO, 400L).toInt()
    val calibrationOffset: Double get() = readDouble(KEY_CAL_OFFSET) ?: 0.0
    val lastEv: Double? get() = readDouble(KEY_LAST_EV)
    val lastApertureFNumber: Double? get() = readDouble(KEY_LAST_APERTURE)
    val lastShutterSeconds: Double? get() = readDouble(KEY_LAST_SHUTTER)

    val lastTakenAt: Long get() = prefs.getLong(KEY_LAST_TAKEN_AT, 0L)
    val lastError: String? get() = prefs.getString(KEY_LAST_ERROR, null)
    val loadingAt: Long get() = prefs.getLong(KEY_LOADING_AT, 0L)

    /** 按 Dart shared_preferences 的 double 编码读：String，去 prefix 后 toDouble()。 */
    private fun readDouble(key: String): Double? {
        if (!prefs.contains(key)) return null
        val raw = prefs.getString(key, null) ?: return null
        val body = if (raw.startsWith(DOUBLE_PREFIX)) raw.substring(DOUBLE_PREFIX.length) else raw
        return body.toDoubleOrNull()
    }

    fun markLoading(now: Long = System.currentTimeMillis()) {
        prefs.edit().putLong(KEY_LOADING_AT, now).apply()
    }

    /** 写时复刻 Dart 端编码：double → String(DOUBLE_PREFIX + value)。 */
    fun writeResult(
        ev: Double,
        apertureFNumber: Double,
        shutterSeconds: Double,
        takenAtMillis: Long,
    ) {
        prefs.edit()
            .putString(KEY_LAST_EV, DOUBLE_PREFIX + ev)
            .putString(KEY_LAST_APERTURE, DOUBLE_PREFIX + apertureFNumber)
            .putString(KEY_LAST_SHUTTER, DOUBLE_PREFIX + shutterSeconds)
            .putLong(KEY_LAST_TAKEN_AT, takenAtMillis)
            .remove(KEY_LAST_ERROR)
            .putLong(KEY_LOADING_AT, 0L)
            .apply()
    }

    fun writeError(code: String) {
        prefs.edit()
            .putString(KEY_LAST_ERROR, code)
            .putLong(KEY_LOADING_AT, 0L)
            .apply()
    }
}
```

- [ ] **Step 2：跑测试**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests "com.zhaoo.filmgo.film_go.widget.WidgetPrefsTest"`
Expected: 全部 6 个 test PASS。

- [ ] **Step 3：commit**

```bash
git add android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/WidgetPrefs.kt \
        android/app/src/test/kotlin/com/zhaoo/filmgo/film_go/widget/WidgetPrefsTest.kt
git commit -m "feat(widget): add WidgetPrefs SharedPreferences wrapper

Reads/writes the keys WidgetBridge (Dart side) writes. Tolerates both
float and long-bits encodings of Dart double values across plugin versions.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

# PR3 — AlsMeter + QuickMeterWidgetProvider + RemoteViews + Manifest

## Task 3.1：新增 widget 资源文件

**Files:**
- Create: `android/app/src/main/res/xml/quick_meter_widget_info.xml`
- Create: `android/app/src/main/res/drawable/widget_bg.xml`
- Create: `android/app/src/main/res/drawable/widget_button_bg.xml`
- Create: `android/app/src/main/res/values/widget_strings.xml`
- Create: `android/app/src/main/res/layout/widget_quick_meter.xml`

- [ ] **Step 1：写 `quick_meter_widget_info.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="110dp"
    android:resizeMode="none"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:widgetCategory="home_screen|keyguard"
    android:initialLayout="@layout/widget_quick_meter"
    android:updatePeriodMillis="0"
    android:previewLayout="@layout/widget_quick_meter" />
```

- [ ] **Step 2：写 `widget_bg.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#000000" />
    <corners android:radius="20dp" />
</shape>
```

- [ ] **Step 3：写 `widget_button_bg.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#FFFFFF" />
    <corners android:radius="14dp" />
</shape>
```

- [ ] **Step 4：写 `widget_strings.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="widget_title">Film·Go</string>
    <string name="widget_empty_hint">按下方按钮测光</string>
    <string name="widget_loading">测光中…</string>
    <string name="widget_btn_measure">测</string>
    <string name="widget_btn_remeasure">再测</string>
    <string name="widget_btn_open_app">打开 App</string>
    <string name="widget_err_no_sensor">设备无环境光传感器</string>
    <string name="widget_err_timeout_first">测光超时，再试一次</string>
    <string name="widget_err_timeout_again">上次超时，再试一次</string>
    <string name="widget_err_out_of_range">超出快门范围</string>
    <string name="widget_quick_meter_label">Film·Go 快速测光</string>
</resources>
```

- [ ] **Step 5：写 `widget_quick_meter.xml`**

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="14dp"
    android:background="@drawable/widget_bg">

    <TextView
        android:id="@+id/widget_title"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:text="@string/widget_title"
        android:textColor="#FFFFFF"
        android:textSize="11sp"
        android:textStyle="bold"
        android:letterSpacing="0.1" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="vertical"
        android:gravity="center_vertical">

        <TextView
            android:id="@+id/widget_primary_line"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textColor="#FFFFFF"
            android:textSize="20sp"
            android:textStyle="bold"
            android:singleLine="true"
            android:text="@string/widget_empty_hint" />

        <TextView
            android:id="@+id/widget_secondary_line"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textColor="#B0B0B0"
            android:textSize="12sp"
            android:singleLine="true"
            android:visibility="gone" />

        <TextView
            android:id="@+id/widget_footnote_line"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:textColor="#FF9F9F"
            android:textSize="11sp"
            android:singleLine="true"
            android:visibility="gone" />
    </LinearLayout>

    <Button
        android:id="@+id/widget_button"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_gravity="center_horizontal"
        android:minWidth="96dp"
        android:minHeight="36dp"
        android:paddingHorizontal="20dp"
        android:background="@drawable/widget_button_bg"
        android:text="@string/widget_btn_measure"
        android:textColor="#000000"
        android:textSize="14sp"
        android:textStyle="bold"
        android:textAllCaps="false" />
</LinearLayout>
```

- [ ] **Step 6：build 验证资源**

Run: `cd android && ./gradlew :app:assembleDebug 2>&1 | tail -20`
Expected: BUILD SUCCESSFUL（不需要新代码引用，资源单纯存在即可）。

- [ ] **Step 7：commit**

```bash
git add android/app/src/main/res/xml/quick_meter_widget_info.xml \
        android/app/src/main/res/drawable/widget_bg.xml \
        android/app/src/main/res/drawable/widget_button_bg.xml \
        android/app/src/main/res/values/widget_strings.xml \
        android/app/src/main/res/layout/widget_quick_meter.xml
git commit -m "feat(widget): add resources for quick-meter app widget

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3.2：实现 `AlsMeter`

**Files:**
- Create: `android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/AlsMeter.kt`

- [ ] **Step 1：写实现**

```kotlin
package com.zhaoo.filmgo.film_go.widget

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

sealed class MeterResult {
    data class Lux(val value: Float) : MeterResult()
    data object NoSensor : MeterResult()
    data object Timeout : MeterResult()
}

/**
 * 注册 TYPE_LIGHT，收第一帧 onSensorChanged 即 unregister 并返回 lux。
 * 1500ms 内未拿到值返回 [MeterResult.Timeout]。无 ALS 返回 [MeterResult.NoSensor]。
 */
object AlsMeter {

    suspend fun measure(context: Context, timeoutMs: Long = 1500): MeterResult {
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sm.getDefaultSensor(Sensor.TYPE_LIGHT) ?: return MeterResult.NoSensor

        val lux = withTimeoutOrNull(timeoutMs) {
            suspendCancellableCoroutine { cont ->
                val listener = object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        if (event.sensor.type != Sensor.TYPE_LIGHT) return
                        val v = event.values[0]
                        // unregister 先做，避免多次回调
                        sm.unregisterListener(this)
                        if (cont.isActive) cont.resume(v)
                    }
                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
                }
                cont.invokeOnCancellation { sm.unregisterListener(listener) }
                sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_FASTEST)
            }
        } ?: return MeterResult.Timeout

        return MeterResult.Lux(lux)
    }
}
```

- [ ] **Step 2：编译验证**

Run: `cd android && ./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL。

- [ ] **Step 3：commit**

```bash
git add android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/AlsMeter.kt
git commit -m "feat(widget): add AlsMeter coroutine wrapper over SensorManager

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3.3：实现 `QuickMeterWidgetProvider`

**Files:**
- Create: `android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/QuickMeterWidgetProvider.kt`

- [ ] **Step 1：写实现**

```kotlin
package com.zhaoo.filmgo.film_go.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import com.zhaoo.filmgo.film_go.MainActivity
import com.zhaoo.filmgo.film_go.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean

class QuickMeterWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ACTION_MEASURE = "com.zhaoo.filmgo.film_go.widget.ACTION_MEASURE"
        private const val ACTION_OPEN_APP = "com.zhaoo.filmgo.film_go.widget.ACTION_OPEN_APP"
        private val inFlight = AtomicBoolean(false)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            renderAndUpdate(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_MEASURE -> handleMeasure(context)
            ACTION_OPEN_APP -> openMainActivity(context)
        }
    }

    private fun handleMeasure(context: Context) {
        if (!inFlight.compareAndSet(false, true)) return  // 二次点击直接退出

        val prefs = WidgetPrefs.from(context)
        prefs.markLoading()
        pushAllWidgets(context)

        val pending = goAsync()
        val appCtx = context.applicationContext  // receiver context 可能短命，用 application
        CoroutineScope(Dispatchers.Default).launch {
            try {
                val result = AlsMeter.measure(appCtx)
                when (result) {
                    is MeterResult.NoSensor -> prefs.writeError("NO_SENSOR")
                    is MeterResult.Timeout -> prefs.writeError("TIMEOUT")
                    is MeterResult.Lux -> {
                        val ev = ExposureMath.fromLux(
                            lux = result.value.toDouble(),
                            iso = prefs.iso,
                            calibrationOffset = prefs.calibrationOffset,
                        )
                        val pair = ExposureMath.medianOrNull(
                            ExposureMath.suggestPairs(ev, prefs.iso),
                        )
                        if (pair == null) {
                            // 仍记录 EV，但走 OUT_OF_RANGE 文案
                            prefs.writeResult(
                                ev = ev,
                                apertureFNumber = prefs.lastApertureFNumber ?: 8.0,
                                shutterSeconds = prefs.lastShutterSeconds ?: (1.0 / 125.0),
                                takenAtMillis = System.currentTimeMillis(),
                            )
                            prefs.writeError("OUT_OF_RANGE")
                        } else {
                            prefs.writeResult(
                                ev = ev,
                                apertureFNumber = pair.apertureFNumber,
                                shutterSeconds = pair.shutterSeconds,
                                takenAtMillis = System.currentTimeMillis(),
                            )
                        }
                    }
                }
            } catch (t: Throwable) {
                prefs.writeError("TIMEOUT")  // 任何意外异常按超时处理
            } finally {
                pushAllWidgets(appCtx)
                inFlight.set(false)
                pending.finish()
            }
        }
    }

    private fun openMainActivity(context: Context) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        context.startActivity(intent)
    }

    private fun pushAllWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, QuickMeterWidgetProvider::class.java))
        for (id in ids) renderAndUpdate(context, mgr, id)
    }

    private fun renderAndUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_meter)
        val prefs = WidgetPrefs.from(context)

        val now = System.currentTimeMillis()
        val loadingAt = prefs.loadingAt
        val loading = loadingAt > 0 && (now - loadingAt) < 2000
        val error = prefs.lastError
        val taken = prefs.lastTakenAt

        when {
            loading -> renderLoading(views)
            error == "NO_SENSOR" -> renderPermanentError(views, context)
            error == "TIMEOUT" && taken == 0L ->
                renderEmptyWithMessage(views, context.getString(R.string.widget_err_timeout_first))
            error == "TIMEOUT" && taken > 0L ->
                renderResult(views, context, prefs,
                    footnote = context.getString(R.string.widget_err_timeout_again))
            error == "OUT_OF_RANGE" -> renderResult(views, context, prefs,
                secondaryOverride = context.getString(R.string.widget_err_out_of_range))
            taken > 0L -> renderResult(views, context, prefs)
            else -> renderEmpty(views, context)
        }

        // 默认整卡片可点击 → 按测光
        views.setOnClickPendingIntent(R.id.widget_button, measureIntent(context))

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun renderEmpty(views: RemoteViews, context: Context) {
        views.setTextViewText(R.id.widget_primary_line, context.getString(R.string.widget_empty_hint))
        views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
        views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
        views.setTextViewText(R.id.widget_button, context.getString(R.string.widget_btn_measure))
    }

    private fun renderEmptyWithMessage(views: RemoteViews, msg: String) {
        views.setTextViewText(R.id.widget_primary_line, msg)
        views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
        views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
    }

    private fun renderLoading(views: RemoteViews) {
        views.setTextViewText(R.id.widget_primary_line, "测光中…")
        views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
        views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
    }

    private fun renderPermanentError(views: RemoteViews, context: Context) {
        views.setTextViewText(R.id.widget_primary_line,
            context.getString(R.string.widget_err_no_sensor))
        views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
        views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
        views.setTextViewText(R.id.widget_button, context.getString(R.string.widget_btn_open_app))
        views.setOnClickPendingIntent(R.id.widget_button, openAppIntent(context))
    }

    private fun renderResult(
        views: RemoteViews,
        context: Context,
        prefs: WidgetPrefs,
        secondaryOverride: String? = null,
        footnote: String? = null,
    ) {
        val ev = prefs.lastEv ?: return renderEmpty(views, context)
        views.setTextViewText(R.id.widget_primary_line, "EV " + formatEv(ev))
        val secondary = secondaryOverride ?: buildString {
            append("f/").append(formatF(prefs.lastApertureFNumber ?: 8.0))
            append(" · ").append(formatShutter(prefs.lastShutterSeconds ?: (1.0 / 125.0)))
            append(" · ISO ").append(prefs.iso)
        }
        views.setTextViewText(R.id.widget_secondary_line, secondary)
        views.setViewVisibility(R.id.widget_secondary_line, View.VISIBLE)
        if (footnote != null) {
            views.setTextViewText(R.id.widget_footnote_line, footnote)
            views.setViewVisibility(R.id.widget_footnote_line, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
        }
        views.setTextViewText(R.id.widget_button, context.getString(R.string.widget_btn_remeasure))
    }

    private fun measureIntent(context: Context): PendingIntent {
        val intent = Intent(context, QuickMeterWidgetProvider::class.java).apply {
            action = ACTION_MEASURE
        }
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, QuickMeterWidgetProvider::class.java).apply {
            action = ACTION_OPEN_APP
        }
        return PendingIntent.getBroadcast(
            context, 1, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun formatEv(ev: Double): String =
        String.format("%.1f", ev)

    private fun formatF(n: Double): String {
        // 整数显示无小数（"f/8"），其他保留 1 位（"f/2.8"），与 Dart Aperture.display 一致
        return if (kotlin.math.abs(n - kotlin.math.round(n)) < 0.05)
            String.format("%.0f", n)
        else
            String.format("%.1f", n)
    }

    private fun formatShutter(sec: Double): String {
        return if (sec >= 1.0) {
            if (kotlin.math.abs(sec - kotlin.math.round(sec)) < 0.01)
                String.format("%.0fs", sec)
            else
                String.format("%.1fs", sec)
        } else {
            val denom = kotlin.math.round(1.0 / sec).toInt()
            "1/$denom"
        }
    }
}
```

- [ ] **Step 2：编译验证**

Run: `cd android && ./gradlew :app:compileDebugKotlin 2>&1 | tail -10`
Expected: BUILD SUCCESSFUL。

- [ ] **Step 3：commit**

```bash
git add android/app/src/main/kotlin/com/zhaoo/filmgo/film_go/widget/QuickMeterWidgetProvider.kt
git commit -m "feat(widget): add QuickMeterWidgetProvider with goAsync ALS pipeline

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3.4：在 `AndroidManifest.xml` 注册 receiver

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1：在 `</application>` 之前插入 `<receiver>`**

```xml
        <receiver
            android:name=".widget.QuickMeterWidgetProvider"
            android:exported="true"
            android:label="@string/widget_quick_meter_label">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
                <action android:name="com.zhaoo.filmgo.film_go.widget.ACTION_MEASURE" />
                <action android:name="com.zhaoo.filmgo.film_go.widget.ACTION_OPEN_APP" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/quick_meter_widget_info" />
        </receiver>
```

- [ ] **Step 2：build + install**

Run: `./scripts/build_android.sh --install`
Expected: BUILD SUCCESSFUL，APK 安装到已连接的小米设备。

- [ ] **Step 3：手动 smoke**

在小米设备上：
1. 长按桌面 → 添加小部件 → 滚到 "Film·Go" → 把 4×2 widget 拖到桌面
2. 点 widget 上的"测"按钮
3. 预期：1-2 秒内显示「EV X.X · f/Y · 1/Z · ISO 400」

如果不显示 widget 入口：检查 logcat `adb logcat | grep -iE "appwidget|filmgo"`，确认 receiver 是否被识别（常见原因：`android:name` 缺少 `.widget.` 前缀）。

- [ ] **Step 4：commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(widget): register QuickMeterWidgetProvider in AndroidManifest

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

# PR4 — 视觉打磨 + Manual QA

## Task 4.1：跑 Manual QA Checklist 并修发现问题

按 spec 第 7.3 节执行 9 项 QA。每发现一个问题就：① 写一行 issue 记录；② fix；③ 同 PR commit 一次。

**Files:** 按 QA 发现的问题修对应文件。常见可能命中的修复点：

- `widget_quick_meter.xml` — 文案被截、字号过大
- `QuickMeterWidgetProvider.formatShutter` — 显示边角 case
- `quick_meter_widget_info.xml` — 在某些桌面尺寸不对

- [ ] **Step 1：跑全 9 项 QA**

按 spec 顺序执行：
1. 冷启 widget
2. ISO 同步
3. HyperOS 锁屏存活
4. 零唤醒（`adb shell dumpsys batterystats --reset` 后挂机 1 小时再 `dumpsys batterystats com.zhaoo.filmgo.film_go`）
5. 无传感器降级（小米机型一般都有 ALS，用 emulator 验）
6. 明暗极端值
7. 二次点击
8. 多 widget 实例
9. 小米桌面 vs Nova

- [ ] **Step 2：记录 QA 结果**

Run:
```bash
mkdir -p docs/superpowers/qa
$EDITOR docs/superpowers/qa/2026-05-25-quick-meter-widget-qa.md
```

在文件里写：

```markdown
# 快速测光 Widget Manual QA - 2026-05-25

| # | 项目 | 结果 | 备注 |
|---|---|---|---|
| 1 | 冷启 widget | ✅/❌ | |
| 2 | ISO 同步 | ✅/❌ | |
| 3 | HyperOS 锁屏存活 | ✅/❌ | |
| 4 | 零唤醒 | ✅/❌ | dumpsys 截图: |
| 5 | 无传感器降级 | ✅/❌ | |
| 6 | 明暗极端值 | ✅/❌ | |
| 7 | 二次点击 | ✅/❌ | |
| 8 | 多 widget 实例 | ✅/❌ | |
| 9 | 小米桌面 ↔ Nova | ✅/❌ | |

性能预算实测：
- 点击 → 出值 P50: ___ ms
- 点击 → 出值 P99: ___ ms
- 24h 待机 widget wake 次数: ___
```

- [ ] **Step 3：commit QA 报告**

```bash
git add docs/superpowers/qa/2026-05-25-quick-meter-widget-qa.md
git commit -m "docs(qa): record manual QA results for quick-meter widget

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 4：所有 QA 通过后，更新 README**

把 README.md「设计与计划」段下追加：

```markdown
- Widget 设计：`docs/superpowers/specs/2026-05-25-quick-meter-widget-design.md`
- Widget 实施：`docs/superpowers/plans/2026-05-25-quick-meter-widget.md`
```

Commit:

```bash
git add README.md
git commit -m "docs(readme): link quick-meter widget design and plan

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

# 完成判定

所有以下条件满足即完成：

- [ ] PR1-PR4 全部 commit 在主线
- [ ] `flutter test` 全绿
- [ ] `cd android && ./gradlew :app:testDebugUnitTest` 全绿
- [ ] `./scripts/build_android.sh` 能 release 打包
- [ ] Manual QA 9 项全部 ✅
- [ ] 性能预算达成：P50 < 800ms、P99 < 1500ms、24h 0 wake
- [ ] QA 报告写入 `docs/superpowers/qa/`
