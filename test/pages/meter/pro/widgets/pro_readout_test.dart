import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:film_go/pages/meter/pro/widgets/pro_readout.dart';
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

  testWidgets('显示快门 + 光圈两行', (tester) async {
    final pair = ExposurePair(
      aperture: Aperture(2.8),
      shutter: ShutterSpeed.seconds(1 / 125),
    );
    await tester.pumpWidget(_wrap(ProReadout(pair: pair)));
    await tester.pumpAndSettle();

    expect(find.text('1/125'), findsOneWidget);
    expect(find.text('f/2.8'), findsOneWidget);
  });

  testWidgets('pair 为 null 时显示 ——', (tester) async {
    await tester.pumpWidget(_wrap(const ProReadout(pair: null)));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsWidgets);
  });
}
