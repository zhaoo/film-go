import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/domain/shared/nd_filter.dart';
import 'package:flutter/painting.dart' show Offset;
import 'package:meta/meta.dart';

/// 测光页顶部 tab 的两种模式。
enum MeterTab { quick, pro }

/// 跨 tab 共享的设置：胶卷 ISO、胶卷 ID、校准偏移。
@immutable
class SharedMeterState {
  final IsoValue iso;
  final String? filmId;
  final double calibrationOffset;

  const SharedMeterState({
    required this.iso,
    required this.filmId,
    required this.calibrationOffset,
  });

  SharedMeterState copyWith({
    IsoValue? iso,
    Object? filmId = _sentinel,
    double? calibrationOffset,
  }) {
    return SharedMeterState(
      iso: iso ?? this.iso,
      filmId: identical(filmId, _sentinel) ? this.filmId : filmId as String?,
      calibrationOffset: calibrationOffset ?? this.calibrationOffset,
    );
  }
}

/// 快速测光 tab 的本地状态。
@immutable
class QuickModeState {
  final EvStop comp;
  final NdFilter filter;
  final double? lockedEv;
  final MeterReading? metered;
  final int? userPairOffset;

  const QuickModeState({
    required this.comp,
    required this.filter,
    required this.lockedEv,
    required this.metered,
    required this.userPairOffset,
  });

  factory QuickModeState.initial() => const QuickModeState(
        comp: EvStop.zero,
        filter: NdFilter.none,
        lockedEv: null,
        metered: null,
        userPairOffset: null,
      );

  QuickModeState copyWith({
    EvStop? comp,
    NdFilter? filter,
    Object? lockedEv = _sentinel,
    Object? metered = _sentinel,
    Object? userPairOffset = _sentinel,
  }) {
    return QuickModeState(
      comp: comp ?? this.comp,
      filter: filter ?? this.filter,
      lockedEv:
          identical(lockedEv, _sentinel) ? this.lockedEv : lockedEv as double?,
      metered: identical(metered, _sentinel)
          ? this.metered
          : metered as MeterReading?,
      userPairOffset: identical(userPairOffset, _sentinel)
          ? this.userPairOffset
          : userPairOffset as int?,
    );
  }
}

/// 专业测光 tab 的本地状态。
@immutable
class ProModeState {
  final EvStop comp;
  final NdFilter filter;
  final MeterMode meterMode;
  final Offset spotCenter;
  final MeterReading? metered;

  const ProModeState({
    required this.comp,
    required this.filter,
    required this.meterMode,
    required this.spotCenter,
    required this.metered,
  });

  factory ProModeState.initial() => const ProModeState(
        comp: EvStop.zero,
        filter: NdFilter.none,
        meterMode: MeterMode.centerWeighted,
        spotCenter: Offset(0.5, 0.5),
        metered: null,
      );

  ProModeState copyWith({
    EvStop? comp,
    NdFilter? filter,
    MeterMode? meterMode,
    Offset? spotCenter,
    Object? metered = _sentinel,
  }) {
    return ProModeState(
      comp: comp ?? this.comp,
      filter: filter ?? this.filter,
      meterMode: meterMode ?? this.meterMode,
      spotCenter: spotCenter ?? this.spotCenter,
      metered: identical(metered, _sentinel)
          ? this.metered
          : metered as MeterReading?,
    );
  }
}

/// 测光页整体状态。
@immutable
class MeterState {
  final MeterTab currentTab;
  final SharedMeterState shared;
  final QuickModeState quick;
  final ProModeState pro;
  final String? errorMessage;

  const MeterState({
    required this.currentTab,
    required this.shared,
    required this.quick,
    required this.pro,
    this.errorMessage,
  });

  factory MeterState.initial() => MeterState(
        currentTab: MeterTab.quick,
        shared: SharedMeterState(
          iso: IsoValue(400),
          filmId: null,
          calibrationOffset: 0,
        ),
        quick: QuickModeState.initial(),
        pro: ProModeState.initial(),
      );

  MeterState copyWith({
    MeterTab? currentTab,
    SharedMeterState? shared,
    QuickModeState? quick,
    ProModeState? pro,
    Object? errorMessage = _sentinel,
  }) {
    return MeterState(
      currentTab: currentTab ?? this.currentTab,
      shared: shared ?? this.shared,
      quick: quick ?? this.quick,
      pro: pro ?? this.pro,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();
