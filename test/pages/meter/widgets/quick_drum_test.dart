import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/domain/shared/nd_filter.dart';
import 'package:film_go/pages/meter/widgets/quick_drum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders four wheel columns with current values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: QuickDrum(
              ev100: 10,
              iso: IsoValue(400),
              comp: EvStop.zero,
              filter: NdFilter.none,
              onEv100Changed: (_) {},
              onIsoChanged: (_) {},
              onCompChanged: (_) {},
              onFilterChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('EV100'), findsOneWidget);
    expect(find.text('ISO'), findsOneWidget);
    expect(find.text('COMP'), findsOneWidget);
    expect(find.text('FILTER'), findsOneWidget);
    // Current values render somewhere in the wheel
    expect(find.text('10'), findsWidgets);
    expect(find.text('400'), findsWidgets);
  });
}
