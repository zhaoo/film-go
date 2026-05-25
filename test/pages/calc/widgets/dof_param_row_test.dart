import 'package:film_go/pages/calc/widgets/dof_param_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DofParamRow', () {
    testWidgets('渲染 label + value + 刻度，无 = H chip', (t) async {
      await t.pumpWidget(
        _wrap(
          DofParamRow(
            label: '焦距',
            displayValue: '50 mm',
            tickLabels: const ['48', '49', '50', '51', '52'],
            activeIndex: 2,
            onIndexChanged: (_) {},
          ),
        ),
      );
      expect(find.text('焦距'), findsOneWidget);
      expect(find.text('50 mm'), findsOneWidget);
      expect(find.text('= H'), findsNothing);
    });

    testWidgets('提供 onSnapToHyperfocal 时显示 = H chip 且可点击', (t) async {
      var snapped = false;
      await t.pumpWidget(
        _wrap(
          DofParamRow(
            label: '对焦距离',
            displayValue: '5 m',
            tickLabels: const ['3', '5', '7'],
            activeIndex: 1,
            onIndexChanged: (_) {},
            onSnapToHyperfocal: () => snapped = true,
          ),
        ),
      );
      expect(find.text('= H'), findsOneWidget);
      await t.tap(find.text('= H'));
      expect(snapped, isTrue);
    });
  });
}
