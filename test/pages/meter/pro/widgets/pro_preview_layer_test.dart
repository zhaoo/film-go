import 'package:film_go/pages/meter/pro/widgets/pro_preview_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('点击时 onTapNormalized 收到 0..1 归一化坐标', (tester) async {
    Offset? got;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 400,
          child: ProPreviewLayer(
            onTapNormalized: (o) => got = o,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    ));

    // 点击预览中的 (50, 200) → 归一化 (0.25, 0.5)
    final r = tester.getRect(find.byType(ProPreviewLayer));
    await tester.tapAt(r.topLeft + const Offset(50, 200));
    await tester.pumpAndSettle();

    expect(got, isNotNull);
    expect(got!.dx, closeTo(0.25, 0.01));
    expect(got!.dy, closeTo(0.5, 0.01));
  });
}
