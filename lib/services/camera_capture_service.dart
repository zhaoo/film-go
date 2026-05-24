import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'watermark_renderer.dart';

typedef CaptureBytesFn = Future<Uint8List> Function();
typedef GallerySaveFn = Future<void> Function(Uint8List bytes, String name);

/// 拍照 → 合成水印 → 写入相册。
///
/// 通过两个回调注入 IO 边界（取图、入相册），让 Service 本身保持纯逻辑、可单测。
/// 默认拍照水印渲染走 [Isolate.run] 防止主线程卡顿；测试场景传 `useIsolate: false`。
class CameraCaptureService {
  final CaptureBytesFn _capture;
  final GallerySaveFn _saveToGallery;
  final bool _useIsolate;

  CameraCaptureService({
    required CaptureBytesFn capture,
    required GallerySaveFn saveToGallery,
    bool useIsolate = true,
  })  : _capture = capture,
        _saveToGallery = saveToGallery,
        _useIsolate = useIsolate;

  Future<void> captureWithWatermark(WatermarkData data) async {
    final raw = await _capture();
    final stamped = _useIsolate
        ? await Isolate.run(
            () => WatermarkRenderer.render(sourceJpeg: raw, data: data),
          )
        : WatermarkRenderer.render(sourceJpeg: raw, data: data);
    await _saveToGallery(stamped, _filenameFor(data.timestamp));
  }

  @visibleForTesting
  static String filenameFor(DateTime t) => _filenameFor(t);

  static String _filenameFor(DateTime t) {
    final stamp = WatermarkRenderer.formatTimestamp(t)
        .replaceAll(' ', '_')
        .replaceAll(':', '')
        .replaceAll('-', '');
    return 'FilmGo_$stamp';
  }
}
