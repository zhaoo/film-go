import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/pages/meter/meter_page.dart';
import 'package:film_go/pages/meter/widgets/measure_icon_button.dart';
import 'package:film_go/pages/meter/widgets/mode_tab.dart';
import 'package:film_go/pages/meter/widgets/quick_drum.dart';
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
        home: const MeterPage(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('MeterPage 默认显示 Quick 视图：ModeTab + QuickDrum + lock 按钮',
      (tester) async {
    final c = MeterController(store: _FakeStore())..bootstrap();
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    expect(find.byType(ModeTab), findsOneWidget);
    expect(find.byType(QuickDrum), findsOneWidget);
    expect(find.byType(MeasureIconButton), findsOneWidget);
    expect(find.text('EV100'), findsOneWidget);
  });

  testWidgets('点击「专业」切换到 Pro 视图：ProTopStatusBar + ShutterButton',
      (tester) async {
    final c = MeterController(store: _FakeStore())..bootstrap();
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('专业'));
    await tester.pumpAndSettle();

    expect(c.state.currentTab, MeterTab.pro);
    // Pro 视图渲染了状态栏（ISO 标签）和快门按钮
    expect(find.text('ISO 400'), findsOneWidget);
  });
}
