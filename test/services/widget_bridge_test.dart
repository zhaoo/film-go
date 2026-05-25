import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/widget_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStore implements CalibrationStoreLike {
  _FakeStore({double initial = 0}) : _v = initial;
  double _v;
  @override
  double read() => _v;
  @override
  Future<void> write(double offset) async => _v = offset;
  @override
  Future<void> clear() async => _v = 0;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetBridge', () {
    test('attach 后立即写入当前 ISO 与校准', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = MeterController(store: _FakeStore())..bootstrap();
      final bridge = WidgetBridge(prefs: prefs);

      bridge.attach(controller);
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getInt('widget.iso'), 400);
      expect(prefs.getDouble('widget.calOffset'), 0.0);
    });

    test('setIso 后 SharedPreferences 同步更新', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = MeterController(store: _FakeStore())..bootstrap();
      WidgetBridge(prefs: prefs).attach(controller);
      await Future<void>.delayed(Duration.zero);

      controller.setIso(IsoValue(800));
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getInt('widget.iso'), 800);
    });

    test('calibrationOffset 变化后 SharedPreferences 同步更新', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = MeterController(store: _FakeStore(initial: 0.42));
      final bridge = WidgetBridge(prefs: prefs);

      bridge.attach(controller);
      await Future<void>.delayed(Duration.zero);

      controller.bootstrap();
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getDouble('widget.calOffset'), 0.42);
    });

    test('detach 后停止写入', () async {
      final prefs = await SharedPreferences.getInstance();
      final controller = MeterController(store: _FakeStore())..bootstrap();
      final bridge = WidgetBridge(prefs: prefs);
      bridge.attach(controller);
      await Future<void>.delayed(Duration.zero);

      bridge.detach();
      controller.setIso(IsoValue(1600));
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getInt('widget.iso'), 400, reason: '已 detach 不应再写');
    });
  });
}
