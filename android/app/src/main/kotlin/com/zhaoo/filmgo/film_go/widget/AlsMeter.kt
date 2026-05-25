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
    object NoSensor : MeterResult()
    object Timeout : MeterResult()
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
            suspendCancellableCoroutine<Float> { cont ->
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
