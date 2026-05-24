import 'dart:math' as math;
import 'dart:typed_data';

import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:meta/meta.dart';

/// 点测的归一化中心点（坐标 0..1）。
@immutable
class SpotCenter {
  const SpotCenter(this.x, this.y);
  final double x;
  final double y;
}

/// 输入字节图的灰度编码格式。
enum LumaFormat {
  /// YUV420 Y 平面，limited range：黑=16，白=235。
  yuvLimited,

  /// 来自 BGRA → 单通道灰度的 full range：黑=0，白=255。
  fullRange,
}

/// 从灰度缓冲区按测光模式提取平均亮度（0..255）。
///
/// Camera 插件给 Android YUV420 时第一个 plane 即 Y；iOS BGRA 需在 Service 层
/// 先转灰度后再传进来。本类纯 Dart，不依赖任何 Flutter / dart:ui，可在
/// isolate 中调用。
class LuminanceExtractor {
  const LuminanceExtractor._();

  static double extract({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    required MeterMode mode,
    SpotCenter? spotCenter,
  }) {
    return switch (mode) {
      MeterMode.average => _rectMean(bytes, bytesPerRow, 0, 0, width, height),
      MeterMode.centerWeighted =>
        _centerWeighted(bytes, width, height, bytesPerRow),
      MeterMode.spot => _spot(bytes, width, height, bytesPerRow, spotCenter),
    };
  }

  /// 提取 ROI 平均灰度并做"limited-range 修正 + sRGB 反 gamma"，输出 0..1 的
  /// 线性灰度 yLinear，用于 [LuminanceToEv.fromCameraFrame]。
  static double extractLinear({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    required MeterMode mode,
    required LumaFormat format,
    SpotCenter? spotCenter,
  }) {
    final mean = extract(
      bytes: bytes,
      width: width,
      height: height,
      bytesPerRow: bytesPerRow,
      mode: mode,
      spotCenter: spotCenter,
    );
    final yNorm = switch (format) {
      LumaFormat.yuvLimited => ((mean - 16) / 219).clamp(0.0, 1.0),
      LumaFormat.fullRange => (mean / 255).clamp(0.0, 1.0),
    };
    return _srgbInverseGamma(yNorm.toDouble());
  }

  /// sRGB 反 gamma：把 0..1 的 gamma 编码灰度还原成线性灰度。
  static double _srgbInverseGamma(double y) {
    if (y <= 0.04045) return y / 12.92;
    return math.pow((y + 0.055) / 1.055, 2.4).toDouble();
  }

  static double _rectMean(
    Uint8List bytes,
    int stride,
    int x0,
    int y0,
    int w,
    int h,
  ) {
    if (w <= 0 || h <= 0) return 0;
    var sum = 0;
    for (var y = y0; y < y0 + h; y++) {
      final rowStart = y * stride;
      for (var x = x0; x < x0 + w; x++) {
        sum += bytes[rowStart + x];
      }
    }
    return sum / (w * h);
  }

  static double _centerWeighted(
    Uint8List bytes,
    int width,
    int height,
    int stride,
  ) {
    final cw = (width * 0.5).round();
    final ch = (height * 0.5).round();
    final cx0 = (width - cw) ~/ 2;
    final cy0 = (height - ch) ~/ 2;
    final centerMean = _rectMean(bytes, stride, cx0, cy0, cw, ch);
    final fullMean = _rectMean(bytes, stride, 0, 0, width, height);
    return centerMean * 0.75 + fullMean * 0.25;
  }

  static double _spot(
    Uint8List bytes,
    int width,
    int height,
    int stride,
    SpotCenter? center,
  ) {
    if (center == null) {
      throw ArgumentError.value(
        center,
        'spotCenter',
        'MeterMode.spot 必须提供 spotCenter',
      );
    }
    final shortSide = width < height ? width : height;
    final size = (shortSide * 0.05).round().clamp(1, shortSide);
    final cx = (center.x * width).round();
    final cy = (center.y * height).round();
    var x0 = cx - size ~/ 2;
    var y0 = cy - size ~/ 2;
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x0 + size > width) x0 = width - size;
    if (y0 + size > height) y0 = height - size;
    return _rectMean(bytes, stride, x0, y0, size, size);
  }
}
