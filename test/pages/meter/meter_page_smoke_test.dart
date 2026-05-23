import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/meter_page.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('MeterPage 渲染并响应手动输入', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          meterControllerProvider.overrideWith(
            (ref) => MeterController(store: _FakeStore())..bootstrap(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MeterPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('取景测光'), findsOneWidget);
    expect(find.textContaining('EV'), findsWidgets);
    expect(find.text('手动'), findsWidgets);
    expect(find.text('点测'), findsOneWidget);

    final manualBtn = find.text('手动输入');
    await tester.scrollUntilVisible(manualBtn, 100);
    await tester.tap(manualBtn);
    await tester.pumpAndSettle();
    expect(find.text('手动输入 EV'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.textContaining('EV 12'), findsOneWidget);
  });
}
