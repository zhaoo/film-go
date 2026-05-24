import 'package:film_go/pages/meter/pro/widgets/shutter_button.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(backgroundColor: Colors.black, body: Center(child: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('点击触发 onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(ShutterButton(onTap: () => taps++)));
    await tester.tap(find.byType(ShutterButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('busy 状态下显示进度圈且不响应点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(
      ShutterButton(busy: true, onTap: () => taps++),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(ShutterButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });
}
