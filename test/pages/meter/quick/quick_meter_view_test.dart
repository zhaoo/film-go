import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/quick/quick_meter_view.dart';
import 'package:film_go/pages/meter/widgets/measure_icon_button.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeStore implements CalibrationStoreLike {
  @override
  double read() => 0;
  @override
  Future<void> write(double offset) async {}
  @override
  Future<void> clear() async {}
}

Widget _wrap(MeterController c) => ProviderScope(
      overrides: [
        meterControllerProvider.overrideWith((ref) => c),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: QuickMeterView(preview: SizedBox.shrink()),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('tapping the lock button toggles quickLock when reading exists',
      (tester) async {
    final c = MeterController(store: _FakeStore())..bootstrap();
    // Seed a metered reading via the controller's public API. We can't drive
    // a frame here without the camera, but quickLockTo lets us pre-populate
    // a known EV.
    c.quickLockTo(10);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    expect(c.state.quick.lockedEv, 10);
    await tester.tap(find.byType(MeasureIconButton));
    await tester.pumpAndSettle();
    expect(c.state.quick.lockedEv, isNull);
  });
}
