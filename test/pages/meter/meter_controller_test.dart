import 'dart:typed_data';

import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCalibrationStore implements CalibrationStoreLike {
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

void main() {
  group('MeterController', () {
    late MeterController c;
    late _FakeCalibrationStore store;

    setUp(() {
      store = _FakeCalibrationStore();
      c = MeterController(store: store);
      c.bootstrap();
    });

    test('初始状态：ISO 400 / 中央重点 / 手动', () {
      expect(c.state.iso.value, 400);
      expect(c.state.mode, MeterMode.centerWeighted);
      expect(c.state.source, MeterSource.manual);
    });

    test('setManualEv 更新 lastReading 与 source', () {
      c.setManualEv(13.5);
      expect(c.state.lastReading?.ev, 13.5);
      expect(c.state.source, MeterSource.manual);
    });

    test('lock 把当前 lastReading 的 EV 冻结到 lockedEv', () {
      c.setManualEv(12);
      c.lock();
      expect(c.state.lockedEv, 12);
      c.setManualEv(15);
      expect(c.state.lockedEv, 12);
      expect(c.state.effectiveEv, 12);
    });

    test('unlock 清除 lockedEv', () {
      c.setManualEv(12);
      c.lock();
      c.unlock();
      expect(c.state.lockedEv, isNull);
    });

    test('processCameraFrame 在 average 模式下计算 EV', () {
      c.setMode(MeterMode.average);
      c.setSource(MeterSource.camera);
      c.processCameraFrame(_solid(100, 100, 128));
      expect(c.state.lastReading, isNotNull);
      expect(c.state.lastReading!.source, MeterSource.camera);
      expect(c.state.lastReading!.ev.isFinite, isTrue);
    });

    test('processLux 计算 EV', () {
      c.setSource(MeterSource.lightSensor);
      c.processLux(2.5);
      expect(c.state.lastReading, isNotNull);
      // lux=2.5 ISO 100 → 0；ISO 400 → +2
      expect(c.state.lastReading!.ev, closeTo(2, 1e-6));
    });

    test('applyCalibration 反推偏移并保存', () async {
      c.setMode(MeterMode.average);
      c.setSource(MeterSource.camera);
      c.processCameraFrame(_solid(10, 10, 128));
      final raw = c.state.lastReading!.ev;
      await c.applyCalibrationFromLastReading(targetEv: 12);
      expect(c.state.calibrationOffset, closeTo(12 - raw, 1e-6));
      expect(store.read(), c.state.calibrationOffset);
      c.processCameraFrame(_solid(10, 10, 128));
      expect(c.state.lastReading!.ev, closeTo(12, 1e-6));
    });
  });
}
