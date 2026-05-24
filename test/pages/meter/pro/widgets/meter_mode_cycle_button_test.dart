import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/pages/meter/pro/widgets/meter_mode_cycle_button.dart';
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

  testWidgets('点击循环 spot → centerWeighted → average → spot', (tester) async {
    final calls = <MeterMode>[];
    var current = MeterMode.spot;
    await tester.pumpWidget(StatefulBuilder(builder: (context, setState) {
      return _wrap(MeterModeCycleButton(
        mode: current,
        onChanged: (m) {
          calls.add(m);
          setState(() => current = m);
        },
      ));
    }));

    await tester.tap(find.byType(MeterModeCycleButton));
    await tester.pumpAndSettle();
    expect(calls.last, MeterMode.centerWeighted);

    await tester.tap(find.byType(MeterModeCycleButton));
    await tester.pumpAndSettle();
    expect(calls.last, MeterMode.average);

    await tester.tap(find.byType(MeterModeCycleButton));
    await tester.pumpAndSettle();
    expect(calls.last, MeterMode.spot);
  });
}
