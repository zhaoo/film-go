package com.zhaoo.filmgo.film_go

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * 测光页用的相机 metadata 通道。
 *
 * 设计目标是和 `camera` 插件已开的 [android.hardware.camera2.CameraCaptureSession]
 * 共用 metadata，但当前 `camera ^0.11.0` 没有暴露 session handle 给第三方插件。
 * 我们暂时把所有方法实现为 no-op：
 * - `isSupported` 仅检查后置摄像头是否 hw level ≥ FULL，但因为我们读不到该 session
 *   的 per-frame metadata，直接返回 `false`，让 Dart 层走降级公式。
 * - `lockAE` / `unlockAE` / `setMeteringPoint` 不动（让 Dart 调用 `camera` 插件
 *   原生方法即可，不通过这里）。
 * - `events` 不发任何帧。
 *
 * 后续若 fork camera 插件暴露 session 引用，再把这里改为真实读取
 * SENSOR_SENSITIVITY / SENSOR_EXPOSURE_TIME / LENS_APERTURE / CONTROL_AE_STATE。
 */
class CameraMetadataPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(checkSupported())
            "lockAE", "unlockAE" -> result.success(null)
            "setMeteringPoint" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // 暂未实现 per-frame metadata 推送。保留接口让 Dart 侧可订阅但不会收到事件。
    }

    override fun onCancel(arguments: Any?) {
        // no-op
    }

    /**
     * 仅作为静态硬件检测：后置摄像头 hw level 是否 ≥ FULL。
     * 即便结果是 true，由于我们目前拿不到 capture session 的 per-frame 回调，
     * 这里始终返回 false，让 Dart 走降级路径；FORK_TODO 之后改回 [hardwareSupported].
     */
    private fun checkSupported(): Boolean = false

    @Suppress("unused")
    private fun hardwareSupported(): Boolean {
        val ctx = context ?: return false
        val mgr = ctx.getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return false
        return try {
            mgr.cameraIdList.any { id ->
                val ch = mgr.getCameraCharacteristics(id)
                val facing = ch.get(CameraCharacteristics.LENS_FACING)
                if (facing != CameraCharacteristics.LENS_FACING_BACK) return@any false
                val level = ch.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL)
                level == CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_FULL ||
                    level == CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL_3
            }
        } catch (_: Throwable) {
            false
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "film_go/camera_metadata"
        private const val EVENT_CHANNEL = "film_go/camera_metadata/events"
    }
}
