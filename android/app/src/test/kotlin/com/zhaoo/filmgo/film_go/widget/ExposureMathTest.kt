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
