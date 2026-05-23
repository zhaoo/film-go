import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeterMode', () {
    test('三种模式定义', () {
      expect(MeterMode.values, hasLength(3));
      expect(MeterMode.values, contains(MeterMode.spot));
      expect(MeterMode.values, contains(MeterMode.centerWeighted));
      expect(MeterMode.values, contains(MeterMode.average));
    });

    test('display 中文标签', () {
      expect(MeterMode.spot.display, '点测');
      expect(MeterMode.centerWeighted.display, '中央重点');
      expect(MeterMode.average.display, '平均');
    });
  });
}
