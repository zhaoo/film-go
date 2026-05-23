import 'dart:async';

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

  Future<bool> initialize() async {
    final cams = await availableCameras();
    if (cams.isEmpty) {
      throw StateError('无可用相机');
    }
    final back = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );
    _controller = CameraController(
      back,
      ResolutionPreset.medium,
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
