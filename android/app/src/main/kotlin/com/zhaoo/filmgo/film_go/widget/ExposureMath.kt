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
