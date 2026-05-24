import 'dart:math' as math;

import 'package:film_go/domain/metering/luminance_to_ev.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LuminanceToEv.fromCameraFrame (EV100)', () {
    test('reference: 18% gray exposed correctly returns EV100 = 0', () {
      // 在中等场景下：N=1.0, t=1s, sensorIso=100, yLinear=0.18 → EV100=0
      final ev = LuminanceToEv.fromCameraFrame(
        aperture: 1.0,
        exposureSec: 1.0,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      expect(ev, closeTo(0, 1e-9));
    });

    test('aperture squared doubles → EV +1', () {
      final base = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 0.01,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      final closed = LuminanceToEv.fromCameraFrame(
        aperture: math.sqrt(2) * 2.0,
        exposureSec: 0.01,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      expect(closed - base, closeTo(1.0, 1e-9));
    });

    test('exposureSec doubled → EV -1', () {
      final fast = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 250,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      final slow = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 125,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      expect(slow - fast, closeTo(-1.0, 1e-9));
    });

    test('sensor ISO doubled → EV -1', () {
      final iso100 = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 125,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      final iso200 = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 125,
        sensorIso: 200,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      expect(iso200 - iso100, closeTo(-1.0, 1e-9));
    });

    test('yLinear doubled → EV +1 (subject is brighter than midgray)', () {
      final dim = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 125,
        sensorIso: 100,
        yLinear: 0.09,
        calibrationOffset: 0,
      );
      final bright = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 125,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      expect(bright - dim, closeTo(1.0, 1e-9));
    });

    test('calibration offset adds directly', () {
      final base = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 125,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      final tuned = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 125,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0.7,
      );
      expect(tuned - base, closeTo(0.7, 1e-9));
    });

    test('Sunny 16: f/16, 1/100s, ISO 100, 18% gray → EV100 ≈ 15', () {
      // 当相机自动曝光打到 Sunny 16 设定时，camera 报出来的 sensor 参数刚好对应
      // 中灰，被测场景的 EV100 就该是 15 ± 0.5。
      final ev = LuminanceToEv.fromCameraFrame(
        aperture: 16,
        exposureSec: 1 / 100,
        sensorIso: 100,
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      expect(ev, closeTo(15, 0.5));
    });

    test('safe floor: yLinear=0 stays finite', () {
      final ev = LuminanceToEv.fromCameraFrame(
        aperture: 2.0,
        exposureSec: 1 / 125,
        sensorIso: 100,
        yLinear: 0,
        calibrationOffset: 0,
      );
      expect(ev.isFinite, isTrue);
      expect(ev, lessThan(-5));
    });
  });

  group('LuminanceToEv.fromGrayMeanFallback', () {
    test('linear y midgray maps to about EV100 ~ log2(0.18·12.5·100) ≈ 7.81',
        () {
      final ev = LuminanceToEv.fromGrayMeanLinearFallback(
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      // log2(0.18 * 12.5 * 100) = log2(225) ≈ 7.814
      expect(ev, closeTo(7.81, 0.05));
    });

    test('yLinear doubled → EV +1', () {
      final dim = LuminanceToEv.fromGrayMeanLinearFallback(
        yLinear: 0.09,
        calibrationOffset: 0,
      );
      final bright = LuminanceToEv.fromGrayMeanLinearFallback(
        yLinear: 0.18,
        calibrationOffset: 0,
      );
      expect(bright - dim, closeTo(1, 1e-9));
    });
  });

  group('LuminanceToEv.calibrationOffsetForFrame', () {
    test('reverse-derives offset such that fromCameraFrame == targetEv', () {
      const targetEv = 14.5;
      final offset = LuminanceToEv.calibrationOffsetForFrame(
        aperture: 8,
        exposureSec: 1 / 125,
        sensorIso: 200,
        yLinear: 0.16,
        targetEv: targetEv,
      );
      final ev = LuminanceToEv.fromCameraFrame(
        aperture: 8,
        exposureSec: 1 / 125,
        sensorIso: 200,
        yLinear: 0.16,
        calibrationOffset: offset,
      );
      expect(ev, closeTo(targetEv, 1e-6));
    });
  });
}
