import 'dart:typed_data';

import 'package:film_go/services/camera_capture_service.dart';
import 'package:film_go/services/watermark_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _solidJpeg(int w, int h, int gray) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(gray, gray, gray));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  final data = WatermarkData(
    iso: 'ISO 400',
    shutter: '1/125',
    aperture: 'f/2.8',
    timestamp: DateTime(2026, 5, 24, 9, 57),
  );

  group('CameraCaptureService.captureWithWatermark', () {
    test('reads source bytes, applies watermark, saves to gallery', () async {
      final src = _solidJpeg(400, 300, 128);
      Uint8List? saved;
      String? savedName;
      final svc = CameraCaptureService(
        capture: () async => src,
        saveToGallery: (bytes, name) async {
          saved = bytes;
          savedName = name;
        },
        useIsolate: false,
      );

      await svc.captureWithWatermark(data);

      expect(saved, isNotNull);
      // Output is a JPEG; same dimensions; differs from input.
      final decoded = img.decodeJpg(saved!)!;
      expect(decoded.width, 400);
      expect(decoded.height, 300);
      expect(saved!.length, isNot(src.length));

      // Filename contains the formatted timestamp (no spaces/colons/dashes).
      expect(savedName, isNotNull);
      expect(savedName, contains('2026'));
      expect(savedName, isNot(contains(':')));
      expect(savedName, isNot(contains(' ')));
    });

    test('propagates failure from gallery save', () async {
      final svc = CameraCaptureService(
        capture: () async => _solidJpeg(40, 30, 128),
        saveToGallery: (_, __) async => throw StateError('disk full'),
        useIsolate: false,
      );
      await expectLater(
        svc.captureWithWatermark(data),
        throwsA(isA<StateError>()),
      );
    });

    test('propagates failure from capture step', () async {
      final svc = CameraCaptureService(
        capture: () async => throw StateError('camera not ready'),
        saveToGallery: (_, __) async {},
        useIsolate: false,
      );
      await expectLater(
        svc.captureWithWatermark(data),
        throwsA(isA<StateError>()),
      );
    });
  });
}
