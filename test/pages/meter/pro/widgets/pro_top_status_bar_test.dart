import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/pages/meter/pro/widgets/pro_top_status_bar.dart';
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

  testWidgets('显示 ISO 与 comp（含正负号）', (tester) async {
    await tester.pumpWidget(_wrap(
      ProTopStatusBar(iso: IsoValue(400), comp: EvStop.thirds(-1)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ISO 400'), findsOneWidget);
    expect(find.textContaining('EV'), findsOneWidget);
    expect(find.textContaining('-1/3'), findsOneWidget);
  });

  testWidgets('comp 为 0 时显示 0', (tester) async {
    await tester.pumpWidget(_wrap(
      ProTopStatusBar(iso: IsoValue(100), comp: EvStop.zero),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ISO 100'), findsOneWidget);
    expect(find.textContaining('0'), findsWidgets);
  });
}
