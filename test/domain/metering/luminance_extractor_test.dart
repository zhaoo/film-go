import 'dart:typed_data';

import 'package:film_go/domain/metering/luminance_extractor.dart';
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构造 [w] × [h] 的常量灰度图（每像素相同 [value]）。
Uint8List solid(int w, int h, int value) {
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = value;
  }
  return out;
}

void main() {
  group('LuminanceExtractor.average', () {
    test('纯白整帧均值 = 255', () {
      final v = LuminanceExtractor.extract(
        bytes: solid(160, 120, 255),
        width: 160,
        height: 120,
        bytesPerRow: 160,
        mode: MeterMode.average,
      );
      expect(v, closeTo(255, 1e-9));
    });

    test('纯黑整帧均值 = 0', () {
      final v = LuminanceExtractor.extract(
        bytes: solid(160, 120, 0),
        width: 160,
        height: 120,
        bytesPerRow: 160,
        mode: MeterMode.average,
      );
      expect(v, closeTo(0, 1e-9));
    });

    test('支持 stride > width（行尾 padding）', () {
      const w = 16;
      const h = 4;
      const stride = 20;
      final bytes = Uint8List(stride * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          bytes[y * stride + x] = 100;
        }
      }
      final v = LuminanceExtractor.extract(
        bytes: bytes,
        width: w,
        height: h,
        bytesPerRow: stride,
        mode: MeterMode.average,
      );
      expect(v, closeTo(100, 1e-9));
    });
  });

  group('LuminanceExtractor.centerWeighted', () {
    test('中心亮、四周暗时，权重偏向中心', () {
      const w = 100;
      const h = 100;
      final bytes = solid(w, h, 50);
      const cx0 = (w - 25) ~/ 2;
      const cy0 = (h - 25) ~/ 2;
      for (var y = cy0; y < cy0 + 25; y++) {
        for (var x = cx0; x < cx0 + 25; x++) {
          bytes[y * w + x] = 200;
        }
      }
      final v = LuminanceExtractor.extract(
        bytes: bytes,
        width: w,
        height: h,
        bytesPerRow: w,
        mode: MeterMode.centerWeighted,
      );
      // 中心 50x50 块内 25x25 = 625 像素是 200，剩余 1875 是 50
      // centerMean = (625*200 + 1875*50)/2500 = 87.5
      // fullMean = (50*100*100 + (200-50)*625)/(100*100) = 50 + 9.375 = 59.375
      // weighted = 87.5*0.75 + 59.375*0.25 = 65.625 + 14.84375 = 80.47
      expect(v, closeTo(80.47, 0.5));
    });
  });

  group('LuminanceExtractor.spot', () {
    test('只对 spotCenter 处的 5% 方形取均值', () {
      const w = 200;
      const h = 100;
      final bytes = solid(w, h, 50);
      // 短边 100，5% = 5px。spotCenter (0.86, 0.87) → (172, 87) 中心 5x5
      // 但实现会按 size~/2 偏移，所以放置范围以中心点 (172, 87) 为中心：(170..174, 85..89)
      for (var y = 85; y < 90; y++) {
        for (var x = 170; x < 175; x++) {
          bytes[y * w + x] = 200;
        }
      }
      final v = LuminanceExtractor.extract(
        bytes: bytes,
        width: w,
        height: h,
        bytesPerRow: w,
        mode: MeterMode.spot,
        spotCenter: const SpotCenter(0.86, 0.87),
      );
      expect(
        v,
        greaterThan(150),
        reason: 'spot 集中在 200 区附近，应远高于背景 50',
      );
    });

    test('spot 模式必须传 spotCenter，否则抛 ArgumentError', () {
      expect(
        () => LuminanceExtractor.extract(
          bytes: solid(10, 10, 50),
          width: 10,
          height: 10,
          bytesPerRow: 10,
          mode: MeterMode.spot,
        ),
        throwsArgumentError,
      );
    });
  });
}
