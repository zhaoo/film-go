import 'package:film_go/services/calibration_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CalibrationStore', () {
    test('未设置时返回 0', () async {
      final s = await CalibrationStore.create();
      expect(s.read(), 0);
    });

    test('write 后再 read 能取回相同值', () async {
      final s = await CalibrationStore.create();
      await s.write(1.5);
      expect(s.read(), 1.5);
    });

    test('clear 复位回 0', () async {
      final s = await CalibrationStore.create();
      await s.write(2.0);
      await s.clear();
      expect(s.read(), 0);
    });
  });
}
