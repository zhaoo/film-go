import 'dart:typed_data';

import 'package:film_go/domain/metering/luminance_extractor.dart';
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List solid(int w, int h, int value) {
  final out = Uint8List(w * h);
  for (var i = 0; i < out.length; i++) {
    out[i] = value;
  }
  return out;
}

void main() {
  group('LuminanceExtractor.extractLinear (sRGB inverse gamma)', () {
    test('YUV limited: Y=16 → 0.0', () {
      final v = LuminanceExtractor.extractLinear(
        bytes: solid(40, 30, 16),
        width: 40,
        height: 30,
        bytesPerRow: 40,
        mode: MeterMode.average,
        format: LumaFormat.yuvLimited,
      );
      expect(v, closeTo(0, 1e-9));
    });

    test('YUV limited: Y=235 → 1.0', () {
      final v = LuminanceExtractor.extractLinear(
        bytes: solid(40, 30, 235),
        width: 40,
        height: 30,
        bytesPerRow: 40,
        mode: MeterMode.average,
        format: LumaFormat.yuvLimited,
      );
      expect(v, closeTo(1, 1e-9));
    });

    test('YUV limited: Y < 16 saturates to 0', () {
      final v = LuminanceExtractor.extractLinear(
        bytes: solid(8, 8, 5),
        width: 8,
        height: 8,
        bytesPerRow: 8,
        mode: MeterMode.average,
        format: LumaFormat.yuvLimited,
      );
      expect(v, closeTo(0, 1e-9));
    });

    test('YUV limited: Y > 235 saturates to 1', () {
      final v = LuminanceExtractor.extractLinear(
        bytes: solid(8, 8, 250),
        width: 8,
        height: 8,
        bytesPerRow: 8,
        mode: MeterMode.average,
        format: LumaFormat.yuvLimited,
      );
      expect(v, closeTo(1, 1e-9));
    });

    test('YUV limited: midgray sRGB ~118 maps to ~0.18 linear', () {
      // sRGB y_norm 0.461 → linear 0.18 per spec §3.2 step 4
      // After limited-range remap: y_norm = (Y - 16) / 219 = 0.461 → Y = 117.0
      final v = LuminanceExtractor.extractLinear(
        bytes: solid(8, 8, 117),
        width: 8,
        height: 8,
        bytesPerRow: 8,
        mode: MeterMode.average,
        format: LumaFormat.yuvLimited,
      );
      expect(v, closeTo(0.18, 0.01));
    });

    test('full range: Y=0 → 0.0, Y=255 → 1.0', () {
      final black = LuminanceExtractor.extractLinear(
        bytes: solid(8, 8, 0),
        width: 8,
        height: 8,
        bytesPerRow: 8,
        mode: MeterMode.average,
        format: LumaFormat.fullRange,
      );
      final white = LuminanceExtractor.extractLinear(
        bytes: solid(8, 8, 255),
        width: 8,
        height: 8,
        bytesPerRow: 8,
        mode: MeterMode.average,
        format: LumaFormat.fullRange,
      );
      expect(black, closeTo(0, 1e-9));
      expect(white, closeTo(1, 1e-9));
    });

    test('full range: midgray sRGB ~118 maps to ~0.18 linear', () {
      // 0.461 * 255 ≈ 117.5 → 0.18
      final v = LuminanceExtractor.extractLinear(
        bytes: solid(8, 8, 118),
        width: 8,
        height: 8,
        bytesPerRow: 8,
        mode: MeterMode.average,
        format: LumaFormat.fullRange,
      );
      expect(v, closeTo(0.18, 0.01));
    });

    test('low values use linear segment (y<=0.04045)', () {
      // sRGB threshold: y_norm = 0.04 → linear ≈ 0.04 / 12.92 ≈ 0.003096
      // With full range: Y = 0.04 * 255 ≈ 10.2
      final v = LuminanceExtractor.extractLinear(
        bytes: solid(8, 8, 10),
        width: 8,
        height: 8,
        bytesPerRow: 8,
        mode: MeterMode.average,
        format: LumaFormat.fullRange,
      );
      expect(v, closeTo(0.00304, 0.0005));
    });

    test('respects MeterMode.spot ROI selection', () {
      const w = 200;
      const h = 100;
      final bytes = solid(w, h, 16); // full black after limited-range
      // Place a hot spot near (172,87): 200 (almost white).
      for (var y = 85; y < 90; y++) {
        for (var x = 170; x < 175; x++) {
          bytes[y * w + x] = 200;
        }
      }
      final v = LuminanceExtractor.extractLinear(
        bytes: bytes,
        width: w,
        height: h,
        bytesPerRow: w,
        mode: MeterMode.spot,
        format: LumaFormat.yuvLimited,
        spotCenter: const SpotCenter(0.86, 0.87),
      );
      expect(
        v,
        greaterThan(0.4),
        reason: 'spot inside the bright patch should be bright',
      );
    });
  });
}
