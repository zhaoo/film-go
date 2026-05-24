import 'dart:typed_data';

import 'package:film_go/services/watermark_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _solidJpeg(int w, int h, int gray) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(gray, gray, gray));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  group('WatermarkRenderer.render', () {
    final sample = WatermarkData(
      iso: 'ISO 400',
      shutter: '1/125',
      aperture: 'f/2.8',
      timestamp: DateTime(2026, 5, 24, 9, 57),
    );

    test('preserves output dimensions', () {
      final src = _solidJpeg(800, 600, 128);
      final out = WatermarkRenderer.render(sourceJpeg: src, data: sample);
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 800);
      expect(decoded.height, 600);
    });

    test('returns valid JPEG bytes', () {
      final src = _solidJpeg(400, 300, 200);
      final out = WatermarkRenderer.render(sourceJpeg: src, data: sample);
      // JPEG SOI marker = 0xFF 0xD8
      expect(out[0], 0xFF);
      expect(out[1], 0xD8);
      // JPEG EOI marker = 0xFF 0xD9 at end
      expect(out[out.length - 2], 0xFF);
      expect(out[out.length - 1], 0xD9);
    });

    test('top-left region preserved (watermark only in bottom-right)', () {
      final src = _solidJpeg(800, 600, 128);
      final out = WatermarkRenderer.render(sourceJpeg: src, data: sample);
      final decoded = img.decodeJpg(out)!;
      // Pixel at (10, 10) should still be ~ gray 128 (JPEG quantization tolerance ±5)
      final p = decoded.getPixel(10, 10);
      expect(p.r, closeTo(128, 8));
      expect(p.g, closeTo(128, 8));
      expect(p.b, closeTo(128, 8));
    });

    test('bottom-right region modified (watermark drawn there)', () {
      final src = _solidJpeg(800, 600, 128);
      final out = WatermarkRenderer.render(sourceJpeg: src, data: sample);
      final decoded = img.decodeJpg(out)!;
      // Sample several pixels inside the watermark band; at least one should
      // differ noticeably from the source 128 background.
      var differs = false;
      for (var dx = 0; dx < 200; dx += 10) {
        for (var dy = 0; dy < 80; dy += 10) {
          final p = decoded.getPixel(800 - 200 + dx, 600 - 80 + dy);
          final delta = (p.r - 128).abs() + (p.g - 128).abs() + (p.b - 128).abs();
          if (delta > 60) {
            differs = true;
            break;
          }
        }
      }
      expect(
        differs,
        isTrue,
        reason: 'expected watermark to alter bottom-right pixels',
      );
    });

    test('formatTimestamp renders yyyy-MM-dd HH:mm with zero padding', () {
      expect(
        WatermarkRenderer.formatTimestamp(DateTime(2026, 1, 5, 9, 7)),
        '2026-01-05 09:07',
      );
      expect(
        WatermarkRenderer.formatTimestamp(DateTime(2026, 12, 31, 23, 59)),
        '2026-12-31 23:59',
      );
    });
  });
}
