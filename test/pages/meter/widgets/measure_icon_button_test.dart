import 'package:film_go/pages/meter/widgets/measure_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows unlocked icon when locked=false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MeasureIconButton(locked: false, onTap: () {}),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(find.byIcon(Icons.lock_outlined), findsNothing);
  });

  testWidgets('shows locked icon when locked=true', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MeasureIconButton(locked: true, onTap: () {}),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
  });

  testWidgets('invokes onTap when pressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MeasureIconButton(locked: false, onTap: () => taps++),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MeasureIconButton));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
