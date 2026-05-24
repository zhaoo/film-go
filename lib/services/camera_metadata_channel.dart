import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// 相机一帧的曝光元数据。由原生 Camera2 / AVFoundation 通道推过来。
@immutable
class CameraMetadataFrame {
  const CameraMetadataFrame({
    required this.sensorIso,
    required this.exposureSec,
    required this.aperture,
    required this.aeConverged,
    required this.timestampUs,
  });

  /// 相机自报的 ISO（不是用户的胶片 ISO）。
  final int sensorIso;

  /// 该帧曝光时间（秒）。
  final double exposureSec;

  /// 镜头光圈 f 值。手机后置定光圈，所以一般是 [CameraCharacteristics] 给的固定值。
  final double aperture;

  /// AE 是否已收敛（converged）。
  final bool aeConverged;

  /// 帧时间戳（微秒），用于和 `CameraImage.lensAperture` 等帧数据对齐。
  final int timestampUs;

  factory CameraMetadataFrame.fromMap(Map<dynamic, dynamic> m) {
    return CameraMetadataFrame(
      sensorIso: (m['sensorIso'] as num).toInt(),
      exposureSec: (m['exposureSec'] as num).toDouble(),
      aperture: (m['aperture'] as num).toDouble(),
      aeConverged: m['aeConverged'] == true,
      timestampUs: (m['timestampUs'] as num).toInt(),
    );
  }
}

/// Dart 侧到原生相机 metadata 桥。
///
/// 仅在 [isSupported] 返回 true 的设备上才能拿到 [frames] 流；否则 Dart 侧
/// 应使用 [LuminanceToEv.fromGrayMeanLinearFallback] 降级公式。
class CameraMetadataChannel {
  CameraMetadataChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _method = methodChannel ?? const MethodChannel(_methodName),
        _event = eventChannel ?? const EventChannel(_eventName);

  static const String _methodName = 'film_go/camera_metadata';
  static const String _eventName = 'film_go/camera_metadata/events';

  final MethodChannel _method;
  final EventChannel _event;

  /// 平台是否支持读取每帧曝光参数。
  ///
  /// Android：要求 INFO_SUPPORTED_HARDWARE_LEVEL ≥ FULL，且原生侧能拿到当前
  /// CaptureSession（取决于宿主 camera 插件版本）。iOS：要求 AVCaptureDevice 已
  /// 由 metadata 通道托管。任何异常都视作不支持。
  Future<bool> isSupported() async {
    try {
      final result = await _method.invokeMethod<bool>('isSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 锁定 AE。Android: CONTROL_AE_LOCK = true；iOS: exposureMode = .locked。
  Future<void> lockAE() => _method.invokeMethod<void>('lockAE');

  /// 解除 AE 锁定。
  Future<void> unlockAE() => _method.invokeMethod<void>('unlockAE');

  /// 设置测光中心点。x/y 为预览归一化坐标 (0..1)。
  Future<void> setMeteringPoint(double x, double y) {
    final cx = x.clamp(0.0, 1.0).toDouble();
    final cy = y.clamp(0.0, 1.0).toDouble();
    return _method.invokeMethod<void>('setMeteringPoint', {'x': cx, 'y': cy});
  }

  Stream<CameraMetadataFrame>? _framesStream;

  /// 持续推送相机帧的曝光 metadata；仅在 [isSupported] = true 时有数据。
  Stream<CameraMetadataFrame> frames() {
    return _framesStream ??= _event.receiveBroadcastStream().map((event) {
      return CameraMetadataFrame.fromMap(event as Map<dynamic, dynamic>);
    });
  }
}
