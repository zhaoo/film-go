import 'dart:typed_data';

import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/domain/shared/nd_filter.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
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
  group('MeterController (regrouped state)', () {
    late MeterController c;
    late _FakeCalibrationStore store;

    setUp(() {
      store = _FakeCalibrationStore();
      c = MeterController(store: store);
      c.bootstrap();
    });

    test('initial state: quick tab + ISO 400 + zero comp/filter', () {
      expect(c.state.currentTab, MeterTab.quick);
      expect(c.state.shared.iso.value, 400);
      expect(c.state.shared.calibrationOffset, 0);
      expect(c.state.quick.comp, EvStop.zero);
      expect(c.state.quick.filter, NdFilter.none);
      expect(c.state.quick.lockedEv, isNull);
      expect(c.state.pro.meterMode, MeterMode.centerWeighted);
      expect(c.state.pro.spotCenter, const Offset(0.5, 0.5));
    });

    test('setTab switches the active tab', () {
      c.setTab(MeterTab.pro);
      expect(c.state.currentTab, MeterTab.pro);
      c.setTab(MeterTab.quick);
      expect(c.state.currentTab, MeterTab.quick);
    });

    test('setIso updates shared ISO across both tabs', () {
      c.setIso(IsoValue(800));
      expect(c.state.shared.iso.value, 800);
      c.setTab(MeterTab.pro);
      expect(c.state.shared.iso.value, 800);
    });

    test('quickSetComp / quickSetFilter affect quick state only', () {
      c.quickSetComp(EvStop.thirds(2)); // +2/3
      c.quickSetFilter(NdFilter.nd4);
      expect(c.state.quick.comp.thirds, 2);
      expect(c.state.quick.filter, NdFilter.nd4);
      expect(c.state.pro.comp.thirds, 0);
      expect(c.state.pro.filter, NdFilter.none);
    });

    test('proSetComp / proSetFilter affect pro state only', () {
      c.proSetComp(EvStop.thirds(-3)); // -1
      c.proSetFilter(NdFilter.nd16);
      expect(c.state.pro.comp.thirds, -3);
      expect(c.state.pro.filter, NdFilter.nd16);
      expect(c.state.quick.comp.thirds, 0);
      expect(c.state.quick.filter, NdFilter.none);
    });

    test('proSetMeterMode and proSetSpotCenter update pro state', () {
      c.proSetMeterMode(MeterMode.spot);
      c.proSetSpotCenter(const Offset(0.2, 0.7));
      expect(c.state.pro.meterMode, MeterMode.spot);
      expect(c.state.pro.spotCenter, const Offset(0.2, 0.7));
    });

    test('quickLock freezes EV from latest reading; quickUnlock clears it', () {
      // Seed a reading via processCameraFrame on the quick tab.
      c.processCameraFrame(_solid(20, 20, 128));
      final ev = c.state.quick.metered!.ev;
      c.quickLock();
      expect(c.state.quick.lockedEv, ev);
      // Subsequent frames must not change locked value.
      c.processCameraFrame(_solid(20, 20, 60));
      expect(c.state.quick.lockedEv, ev);
      c.quickUnlock();
      expect(c.state.quick.lockedEv, isNull);
    });

    test('processCameraFrame on quick tab updates quick.metered', () {
      c.setTab(MeterTab.quick);
      c.processCameraFrame(_solid(40, 30, 128));
      expect(c.state.quick.metered, isNotNull);
      expect(c.state.quick.metered!.ev.isFinite, isTrue);
      // Pro stays empty.
      expect(c.state.pro.metered, isNull);
    });

    test('processCameraFrame on pro tab updates pro.metered', () {
      c.setTab(MeterTab.pro);
      c.proSetMeterMode(MeterMode.average);
      c.processCameraFrame(_solid(40, 30, 128));
      expect(c.state.pro.metered, isNotNull);
      expect(c.state.pro.metered!.ev.isFinite, isTrue);
      // Quick stays empty.
      expect(c.state.quick.metered, isNull);
    });

    test('applyCalibrationFromLastReading writes offset and adjusts shared',
        () async {
      c.processCameraFrame(_solid(10, 10, 128));
      final raw = c.state.quick.metered!.ev;
      await c.applyCalibrationFromLastReading(targetEv: 12);
      expect(c.state.shared.calibrationOffset, closeTo(12 - raw, 1e-6));
      expect(store.read(), c.state.shared.calibrationOffset);
    });

    test('userPairOffset 默认 null，quickSetPairOffset 写入', () {
      expect(c.state.quick.userPairOffset, isNull);
      c.quickSetPairOffset(2);
      expect(c.state.quick.userPairOffset, 2);
      c.quickSetPairOffset(-1);
      expect(c.state.quick.userPairOffset, -1);
    });

    test('quickResetPairOffset 清回 null', () {
      c.quickSetPairOffset(3);
      c.quickResetPairOffset();
      expect(c.state.quick.userPairOffset, isNull);
    });

    test('切 ISO/COMP/FILTER 不重置 userPairOffset', () {
      c.quickSetPairOffset(1);
      c.setIso(IsoValue(800));
      c.quickSetComp(EvStop.thirds(1));
      c.quickSetFilter(NdFilter.nd4);
      expect(c.state.quick.userPairOffset, 1);
    });
  });
}
