import 'package:film_go/pages/meter/pro/widgets/spot_overlay.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(backgroundColor: Colors.black, body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('visible=false 时不渲染框', (tester) async {
    await tester.pumpWidget(_wrap(
      const SizedBox(
        width: 300,
        height: 400,
        child: SpotOverlay(center: Offset(0.5, 0.5), visible: false),
      ),
    ),);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('spot-frame')), findsNothing);
  });

  testWidgets('visible=true 时按 0..1 比例放置 56×56 框', (tester) async {
    await tester.pumpWidget(_wrap(
      const SizedBox(
        width: 200,
        height: 400,
        child: SpotOverlay(center: Offset(0.25, 0.5), visible: true),
      ),
    ),);
    await tester.pumpAndSettle();

    final frame = find.byKey(const ValueKey('spot-frame'));
    expect(frame, findsOneWidget);

    final size = tester.getSize(frame);
    expect(size.width, 56);
    expect(size.height, 56);

    // center 应位于 200*0.25 = 50 px 横向；框中心在 50 px。
    final rect = tester.getRect(frame);
    expect(rect.center.dx, closeTo(50, 0.5));
    expect(rect.center.dy, closeTo(200, 0.5));
  });
}
