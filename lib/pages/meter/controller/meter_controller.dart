import 'package:film_go/domain/metering/luminance_extractor.dart';
import 'package:film_go/domain/metering/luminance_to_ev.dart';
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/domain/shared/nd_filter.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeterController extends ChangeNotifier {
  MeterController({required CalibrationStoreLike store})
      : _store = store,
        _state = MeterState.initial();

  final CalibrationStoreLike _store;
  MeterState _state;
  MeterState get state => _state;

  void _set(MeterState s) {
    _state = s;
    notifyListeners();
  }

  void bootstrap() {
    _set(
      _state.copyWith(
        shared: _state.shared.copyWith(calibrationOffset: _store.read()),
      ),
    );
  }

  // ---- shared ------------------------------------------------------------

  void setTab(MeterTab tab) => _set(_state.copyWith(currentTab: tab));

  void setIso(IsoValue iso) =>
      _set(_state.copyWith(shared: _state.shared.copyWith(iso: iso)));

  void setFilmId(String? id) =>
      _set(_state.copyWith(shared: _state.shared.copyWith(filmId: id)));

  // ---- quick -------------------------------------------------------------

  void quickSetComp(EvStop comp) =>
      _set(_state.copyWith(quick: _state.quick.copyWith(comp: comp)));

  void quickSetFilter(NdFilter filter) =>
      _set(_state.copyWith(quick: _state.quick.copyWith(filter: filter)));

  void quickLock() {
    final ev = _state.quick.metered?.ev;
    if (ev == null) return;
    _set(_state.copyWith(quick: _state.quick.copyWith(lockedEv: ev)));
  }

  void quickUnlock() =>
      _set(_state.copyWith(quick: _state.quick.copyWith(lockedEv: null)));

  /// 直接把 quick 锁定到一个具体 EV100（drum 的 EV100 列滚动用）。
  void quickLockTo(double ev) =>
      _set(_state.copyWith(quick: _state.quick.copyWith(lockedEv: ev)));

  // ---- pro ---------------------------------------------------------------

  void proSetComp(EvStop comp) =>
      _set(_state.copyWith(pro: _state.pro.copyWith(comp: comp)));

  void proSetFilter(NdFilter filter) =>
      _set(_state.copyWith(pro: _state.pro.copyWith(filter: filter)));

  void proSetMeterMode(MeterMode mode) =>
      _set(_state.copyWith(pro: _state.pro.copyWith(meterMode: mode)));

  void proSetSpotCenter(Offset center) =>
      _set(_state.copyWith(pro: _state.pro.copyWith(spotCenter: center)));

  // ---- camera ingest -----------------------------------------------------

  num? _lastGrayMean;

  /// 处理一帧灰度图。当前 tab 决定 ROI 与目标状态。
  ///
  /// PR6 阶段沿用旧的 `LuminanceExtractor.extract` + `LuminanceToEv.fromGrayMean`
  /// 通道；PR7/PR8 接入相机 metadata + 线性 gamma 公式。
  void processCameraFrame(GrayFrame frame) {
    final tab = _state.currentTab;
    final mode = tab == MeterTab.pro ? _state.pro.meterMode : MeterMode.average;
    final spot = tab == MeterTab.pro
        ? SpotCenter(_state.pro.spotCenter.dx, _state.pro.spotCenter.dy)
        : const SpotCenter(0.5, 0.5);
    final mean = LuminanceExtractor.extract(
      bytes: frame.bytes,
      width: frame.width,
      height: frame.height,
      bytesPerRow: frame.bytesPerRow,
      mode: mode,
      spotCenter: spot,
    );
    _lastGrayMean = mean;
    final ev = LuminanceToEv.fromGrayMean(
      grayMean: mean,
      iso: _state.shared.iso,
      calibrationOffset: _state.shared.calibrationOffset,
    );
    final reading = MeterReading(
      ev: ev,
      iso: _state.shared.iso,
      mode: mode,
      source: MeterSource.camera,
      takenAt: DateTime.now(),
    );
    if (tab == MeterTab.pro) {
      _set(_state.copyWith(pro: _state.pro.copyWith(metered: reading)));
    } else {
      _set(_state.copyWith(quick: _state.quick.copyWith(metered: reading)));
    }
  }

  // ---- calibration -------------------------------------------------------

  Future<void> applyCalibrationFromLastReading({
    required double targetEv,
  }) async {
    final mean = _lastGrayMean;
    if (mean == null) return;
    final offset = LuminanceToEv.calibrationOffsetFor(
      grayMean: mean,
      iso: _state.shared.iso,
      targetEv: targetEv,
    );
    await _store.write(offset);
    _set(
      _state.copyWith(
        shared: _state.shared.copyWith(calibrationOffset: offset),
      ),
    );
  }

  Future<void> resetCalibration() async {
    await _store.clear();
    _set(
      _state.copyWith(
        shared: _state.shared.copyWith(calibrationOffset: 0),
      ),
    );
  }
}

final meterControllerProvider = ChangeNotifierProvider<MeterController>((ref) {
  throw UnimplementedError(
    'meterControllerProvider 必须在 ProviderScope 中 override',
  );
});
