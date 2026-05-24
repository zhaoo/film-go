import Flutter
import UIKit
import AVFoundation

/// 测光页用的相机 metadata 通道（iOS 端骨架）。
///
/// 设计目标是与已运行的 `camera` 插件 AVCaptureSession 共用 metadata，
/// 但 `camera ^0.11.0` 没有把 session handle 暴露给第三方插件，
/// 我们暂时把所有方法实现为 no-op：
/// - `isSupported` 静态硬件层面检查能否拿到默认后置摄像头，但因为我们读不到
///   该 session 的 per-frame metadata，直接返回 `false`，让 Dart 层走降级公式。
/// - `lockAE` / `unlockAE` / `setMeteringPoint` 不动（Dart 通过 `camera` 插件
///   原生方法即可，不通过这里）。
/// - `events` 不发任何帧。
///
/// 后续若 fork camera 插件暴露 session 引用，这里改为真实读取
/// AVCaptureDevice.iso / exposureDuration / lensAperture / KVO converged 状态。
public class CameraMetadataPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private static let methodChannelName = "film_go/camera_metadata"
    private static let eventChannelName = "film_go/camera_metadata/events"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = CameraMetadataPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(checkSupported())
        case "lockAE", "unlockAE", "setMeteringPoint":
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // 暂未实现 per-frame metadata 推送。保留接口让 Dart 侧可订阅但不会收到事件。
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }

    /// 即便后置摄像头存在，由于我们目前拿不到 capture session 的 per-frame 回调，
    /// 这里始终返回 false，让 Dart 走降级路径；FORK_TODO 之后改回 [hardwareSupported].
    private func checkSupported() -> Bool {
        return false
    }

    @available(iOS 10.0, *)
    private func hardwareSupported() -> Bool {
        return AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) != nil
    }
}
