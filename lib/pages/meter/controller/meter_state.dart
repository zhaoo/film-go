import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:meta/meta.dart';

@immutable
class MeterState {
  const MeterState({
    required this.iso,
    required this.mode,
    required this.source,
    required this.calibrationOffset,
    this.lastReading,
    this.lockedEv,
    this.errorMessage,
    this.permissionGranted = false,
  });

  factory MeterState.initial() => MeterState(
        iso: IsoValue(400),
        mode: MeterMode.centerWeighted,
        source: MeterSource.manual,
        calibrationOffset: 0,
      );

  final IsoValue iso;
  final MeterMode mode;
  final MeterSource source;
  final double calibrationOffset;
  final MeterReading? lastReading;
  final double? lockedEv;
  final String? errorMessage;
  final bool permissionGranted;

  /// 当前实际用于推荐曝光组合的 EV：优先 locked，其次 lastReading.ev。
  double? get effectiveEv => lockedEv ?? lastReading?.ev;

  MeterState copyWith({
    IsoValue? iso,
    MeterMode? mode,
    MeterSource? source,
    double? calibrationOffset,
    MeterReading? lastReading,
    Object? lockedEv = _sentinel,
    Object? errorMessage = _sentinel,
    bool? permissionGranted,
  }) {
    return MeterState(
      iso: iso ?? this.iso,
      mode: mode ?? this.mode,
      source: source ?? this.source,
      calibrationOffset: calibrationOffset ?? this.calibrationOffset,
      lastReading: lastReading ?? this.lastReading,
      lockedEv: identical(lockedEv, _sentinel)
          ? this.lockedEv
          : lockedEv as double?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }
}

const Object _sentinel = Object();
