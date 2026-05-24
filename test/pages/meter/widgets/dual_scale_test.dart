import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:film_go/pages/meter/widgets/dual_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders one row per pair with shutter and aperture',
      (tester) async {
    final pairs = [
      ExposurePair(
        aperture: Aperture(2.8),
        shutter: ShutterSpeed.seconds(1 / 250),
      ),
      ExposurePair(
        aperture: Aperture(4),
        shutter: ShutterSpeed.seconds(1 / 125),
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 400,
            child: DualScale(pairs: pairs, highlightIndex: 0),
          ),
        ),
      ),
    );

    expect(find.text('1/250'), findsOneWidget);
    expect(find.text('1/125'), findsOneWidget);
    expect(find.text('f/2.8'), findsOneWidget);
    expect(find.text('f/4'), findsOneWidget);
  });

  testWidgets('renders empty placeholder when pairs is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 100,
            height: 400,
            child: DualScale(pairs: [], highlightIndex: 0),
          ),
        ),
      ),
    );
    expect(find.text('—'), findsWidgets);
  });
}
