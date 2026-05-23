import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeterReading', () {
    test('字段保留与读取', () {
      final at = DateTime(2026, 5, 24, 12);
      final r = MeterReading(
        ev: 14.5,
        iso: IsoValue(100),
        mode: MeterMode.centerWeighted,
        source: MeterSource.camera,
        takenAt: at,
      );
      expect(r.ev, 14.5);
      expect(r.iso.value, 100);
      expect(r.mode, MeterMode.centerWeighted);
      expect(r.source, MeterSource.camera);
      expect(r.takenAt, at);
    });

    test('copyWith 不影响其他字段', () {
      final r = MeterReading(
        ev: 14.5,
        iso: IsoValue(100),
        mode: MeterMode.average,
        source: MeterSource.manual,
        takenAt: DateTime(2026),
      );
      final updated = r.copyWith(ev: 15);
      expect(updated.ev, 15);
      expect(updated.iso, r.iso);
      expect(updated.mode, r.mode);
      expect(updated.source, r.source);
      expect(updated.takenAt, r.takenAt);
    });
  });

  group('MeterSource', () {
    test('display 中文标签', () {
      expect(MeterSource.camera.display, '相机');
      expect(MeterSource.lightSensor.display, '传感器');
      expect(MeterSource.manual.display, '手动');
    });
  });
}
