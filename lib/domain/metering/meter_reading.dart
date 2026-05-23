import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:meta/meta.dart';

/// 一次测光的来源。
enum MeterSource {
  camera,
  lightSensor,
  manual;

  String get display => switch (this) {
        MeterSource.camera => '相机',
        MeterSource.lightSensor => '传感器',
        MeterSource.manual => '手动',
      };
}

/// 一次测光快照。
@immutable
class MeterReading {
  const MeterReading({
    required this.ev,
    required this.iso,
    required this.mode,
    required this.source,
    required this.takenAt,
  });

  final double ev;
  final IsoValue iso;
  final MeterMode mode;
  final MeterSource source;
  final DateTime takenAt;

  MeterReading copyWith({
    double? ev,
    IsoValue? iso,
    MeterMode? mode,
    MeterSource? source,
    DateTime? takenAt,
  }) {
    return MeterReading(
      ev: ev ?? this.ev,
      iso: iso ?? this.iso,
      mode: mode ?? this.mode,
      source: source ?? this.source,
      takenAt: takenAt ?? this.takenAt,
    );
  }
}
