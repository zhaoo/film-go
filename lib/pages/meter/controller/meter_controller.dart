import 'package:film_go/domain/metering/luminance_extractor.dart';
import 'package:film_go/domain/metering/luminance_to_ev.dart';
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeterController extends ChangeNotifier {
  MeterController({required CalibrationStoreLike store}) : _store = store {
    _state = MeterState.initial();
  }

  final CalibrationStoreLike _store;
  late MeterState _state;
  MeterState get state => _state;

  void _set(MeterState s) {
    _state = s;
    notifyListeners();
  }

  void bootstrap() {
    _set(_state.copyWith(calibrationOffset: _store.read()));
  }

  void setIso(IsoValue iso) => _set(_state.copyWith(iso: iso));
  void setMode(MeterMode mode) => _set(_state.copyWith(mode: mode));
  void setSource(MeterSource source) => _set(_state.copyWith(source: source));

  void setManualEv(double ev) {
    _set(_state.copyWith(
      source: MeterSource.manual,
      lastReading: MeterReading(
        ev: ev,
        iso: _state.iso,
        mode: _state.mode,
        source: MeterSource.manual,
        takenAt: DateTime.now(),
      ),
    ),);
  }

  void lock() {
    final ev = _state.lastReading?.ev;
    if (ev == null) return;
    _set(_state.copyWith(lockedEv: ev));
  }

  void unlock() {
    _set(_state.copyWith(lockedEv: null));
  }

  num? _lastGrayMean;

  void processCameraFrame(GrayFrame frame, {SpotCenter? spotCenter}) {
    final mean = LuminanceExtractor.extract(
      bytes: frame.bytes,
      width: frame.width,
      height: frame.height,
      bytesPerRow: frame.bytesPerRow,
      mode: _state.mode,
      spotCenter: spotCenter ?? const SpotCenter(0.5, 0.5),
    );
    _lastGrayMean = mean;
    final ev = LuminanceToEv.fromGrayMean(
      grayMean: mean,
      iso: _state.iso,
      calibrationOffset: _state.calibrationOffset,
    );
    _set(_state.copyWith(
      source: MeterSource.camera,
      lastReading: MeterReading(
        ev: ev,
        iso: _state.iso,
        mode: _state.mode,
        source: MeterSource.camera,
        takenAt: DateTime.now(),
      ),
    ),);
  }

  void processLux(num lux) {
    final ev = LuminanceToEv.fromLux(
      lux: lux,
      iso: _state.iso,
      calibrationOffset: _state.calibrationOffset,
    );
    _set(_state.copyWith(
      source: MeterSource.lightSensor,
      lastReading: MeterReading(
        ev: ev,
        iso: _state.iso,
        mode: _state.mode,
        source: MeterSource.lightSensor,
        takenAt: DateTime.now(),
      ),
    ),);
  }

  Future<void> applyCalibrationFromLastReading({
    required double targetEv,
  }) async {
    final mean = _lastGrayMean;
    if (mean == null) return;
    final offset = LuminanceToEv.calibrationOffsetFor(
      grayMean: mean,
      iso: _state.iso,
      targetEv: targetEv,
    );
    await _store.write(offset);
    _set(_state.copyWith(
      calibrationOffset: offset,
      lastReading: _state.lastReading?.copyWith(ev: targetEv),
    ),);
  }

  Future<void> resetCalibration() async {
    await _store.clear();
    _set(_state.copyWith(calibrationOffset: 0));
  }
}

final meterControllerProvider = ChangeNotifierProvider<MeterController>((ref) {
  throw UnimplementedError(
    'meterControllerProvider 必须在 ProviderScope 中 override',
  );
});
