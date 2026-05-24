import 'package:film_go/domain/metering/luminance_extractor.dart';
import 'package:film_go/domain/metering/luminance_to_ev.dart';
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/domain/shared/nd_filter.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/camera_metadata_channel.dart';
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

  double? _lastYLinear;
  CameraMetadataFrame? _lastMeta;
  bool _metadataSupported = false;
  MeterMode _lastMode = MeterMode.average;

  /// 显式标记原生 metadata 是否可用。
  ///
  /// 默认 false：使用 [LuminanceToEv.fromGrayMeanLinearFallback] 降级公式；
  /// MeterPage 在 `CameraMetadataChannel.isSupported()` 返回 true 后传 true。
  void setMetadataSupported(bool supported) {
    _metadataSupported = supported;
    _recompute();
  }

  /// 拿到一帧相机灰度：算 yLinear、缓存、合并 metadata 推 EV。
  ///
  /// [format] 决定如何把 0..255 灰度归一化：YUV plane 用 [LumaFormat.yuvLimited]；
  /// BGRA→灰度后用 [LumaFormat.fullRange]（也是测试默认）。
  void processCameraFrame(
    GrayFrame frame, {
    LumaFormat format = LumaFormat.fullRange,
  }) {
    final tab = _state.currentTab;
    final mode = tab == MeterTab.pro ? _state.pro.meterMode : MeterMode.average;
    final spot = tab == MeterTab.pro
        ? SpotCenter(_state.pro.spotCenter.dx, _state.pro.spotCenter.dy)
        : const SpotCenter(0.5, 0.5);
    _lastYLinear = LuminanceExtractor.extractLinear(
      bytes: frame.bytes,
      width: frame.width,
      height: frame.height,
      bytesPerRow: frame.bytesPerRow,
      mode: mode,
      format: format,
      spotCenter: spot,
    );
    _lastMode = mode;
    _recompute();
  }

  /// 拿到一帧相机 metadata：缓存并合并 yLinear 推 EV。
  void processCameraMetadata(CameraMetadataFrame meta) {
    _lastMeta = meta;
    if (!_metadataSupported) {
      _metadataSupported = true;
    }
    _recompute();
  }

  void _recompute() {
    final y = _lastYLinear;
    if (y == null) return;
    final double ev;
    final useMeta = _metadataSupported && _lastMeta != null;
    if (useMeta) {
      final m = _lastMeta!;
      ev = LuminanceToEv.fromCameraFrame(
        aperture: m.aperture,
        exposureSec: m.exposureSec,
        sensorIso: m.sensorIso,
        yLinear: y,
        calibrationOffset: _state.shared.calibrationOffset,
      );
    } else {
      ev = LuminanceToEv.fromGrayMeanLinearFallback(
        yLinear: y,
        calibrationOffset: _state.shared.calibrationOffset,
      );
    }
    final reading = MeterReading(
      ev: ev,
      iso: _state.shared.iso,
      mode: _lastMode,
      source: MeterSource.camera,
      takenAt: DateTime.now(),
    );
    if (_state.currentTab == MeterTab.pro) {
      _set(_state.copyWith(pro: _state.pro.copyWith(metered: reading)));
    } else {
      _set(_state.copyWith(quick: _state.quick.copyWith(metered: reading)));
    }
  }

  // ---- calibration -------------------------------------------------------

  Future<void> applyCalibrationFromLastReading({
    required double targetEv,
  }) async {
    final y = _lastYLinear;
    if (y == null) return;
    final double offset;
    if (_metadataSupported && _lastMeta != null) {
      final m = _lastMeta!;
      offset = LuminanceToEv.calibrationOffsetForFrame(
        aperture: m.aperture,
        exposureSec: m.exposureSec,
        sensorIso: m.sensorIso,
        yLinear: y,
        targetEv: targetEv,
      );
    } else {
      final raw = LuminanceToEv.fromGrayMeanLinearFallback(
        yLinear: y,
        calibrationOffset: 0,
      );
      offset = targetEv - raw;
    }
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
