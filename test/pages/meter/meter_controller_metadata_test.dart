import 'dart:math' as math;
import 'dart:typed_data';

import 'package:film_go/domain/metering/luminance_to_ev.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/camera_metadata_channel.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Store implements CalibrationStoreLike {
  double _v = 0;
  @override
  double read() => _v;
  @override
  Future<void> write(double v) async => _v = v;
  @override
  Future<void> clear() async => _v = 0;
}

GrayFrame _solid(int w, int h, int v) {
  final b = Uint8List(w * h);
  for (var i = 0; i < b.length; i++) {
    b[i] = v;
  }
  return GrayFrame(bytes: b, width: w, height: h, bytesPerRow: w);
}

CameraMetadataFrame _meta({
  int sensorIso = 200,
  double exposureSec = 1 / 60,
  double aperture = 1.8,
  bool aeConverged = true,
}) =>
    CameraMetadataFrame(
      sensorIso: sensorIso,
      exposureSec: exposureSec,
      aperture: aperture,
      aeConverged: aeConverged,
      timestampUs: 0,
    );

double _ySrgb(double n) {
  if (n <= 0.04045) return n / 12.92;
  return math.pow((n + 0.055) / 1.055, 2.4).toDouble();
}

void main() {
  test('processCameraMetadata + processCameraFrame：用 fromCameraFrame 公式算 EV',
      () {
    final c = MeterController(store: _Store())..bootstrap();
    c.setMetadataSupported(true);
    c.processCameraMetadata(
        _meta(sensorIso: 200, exposureSec: 1 / 60, aperture: 1.8));
    c.processCameraFrame(_solid(20, 20, 128));

    final reading = c.state.quick.metered!;
    final expected = LuminanceToEv.fromCameraFrame(
      aperture: 1.8,
      exposureSec: 1 / 60,
      sensorIso: 200,
      yLinear: _ySrgb(128 / 255),
      calibrationOffset: 0,
    );
    expect(reading.ev, closeTo(expected, 0.05));
  });

  test('metadata 不支持时使用 fromGrayMeanLinearFallback', () {
    final c = MeterController(store: _Store())..bootstrap();
    c.processCameraFrame(_solid(20, 20, 128));
    final reading = c.state.quick.metered!;
    final expected = LuminanceToEv.fromGrayMeanLinearFallback(
      yLinear: _ySrgb(128 / 255),
      calibrationOffset: 0,
    );
    expect(reading.ev, closeTo(expected, 0.05));
  });
}
