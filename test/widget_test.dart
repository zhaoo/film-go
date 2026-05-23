import 'package:film_go/app.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/services/calibration_store.dart';
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

ProviderScope _wrap() => ProviderScope(
      overrides: [
        meterControllerProvider.overrideWith(
          (ref) => MeterController(store: _FakeStore())..bootstrap(),
        ),
      ],
      child: const FilmGoApp(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('App 启动后默认进入 Meter Tab', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('取景'), findsOneWidget);
    expect(find.text('计算'), findsOneWidget);
    expect(find.text('胶卷'), findsOneWidget);
    expect(find.text('暗房'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('点击「计算」Tab 切换到 Calc 页', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('计算'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Calc'), findsOneWidget);
  });
}
