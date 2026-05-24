import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:film_go/pages/meter/pro/widgets/scale_strip.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(backgroundColor: Colors.black, body: child),
    );

ExposurePair _p(double f, double sec) => ExposurePair(
      aperture: Aperture(f),
      shutter: ShutterSpeed.seconds(sec),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('空 pairs：渲染中央 — 占位', (tester) async {
    await tester.pumpWidget(_wrap(
      const SizedBox(
          height: 80, child: ScaleStrip(pairs: [], highlightIndex: 0)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('非空 pairs：所有快门/光圈值都渲染', (tester) async {
    final pairs = [
      _p(2, 1 / 250),
      _p(2.8, 1 / 125),
      _p(4, 1 / 60),
    ];
    await tester.pumpWidget(_wrap(
      SizedBox(
        height: 80,
        width: 600,
        child: ScaleStrip(pairs: pairs, highlightIndex: 1),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('f/2'), findsOneWidget);
    expect(find.text('f/2.8'), findsOneWidget);
    expect(find.text('f/4'), findsOneWidget);
    expect(find.text('1/250'), findsOneWidget);
    expect(find.text('1/125'), findsOneWidget);
    expect(find.text('1/60'), findsOneWidget);
  });
}
