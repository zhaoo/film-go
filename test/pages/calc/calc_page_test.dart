import 'package:film_go/pages/calc/calc_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(home: child),
    );

void main() {
  group('CalcPage', () {
    testWidgets('渲染 5 段：可视化 + 4 行参数 + 弥散圆只读', (t) async {
      await t.pumpWidget(_wrap(const CalcPage()));
      await t.pumpAndSettle();
      expect(find.text('对焦距离'), findsOneWidget);
      expect(find.text('焦距'), findsOneWidget);
      expect(find.text('光圈'), findsOneWidget);
      expect(find.text('画幅'), findsOneWidget);
      expect(find.text('弥散圆 c'), findsOneWidget);
      // 摘要行（H = ）
      expect(find.textContaining('H ='), findsOneWidget);
    });

    testWidgets('点 = H chip → 对焦距离值更新成 10m 显示', (t) async {
      await t.pumpWidget(_wrap(const CalcPage()));
      await t.pumpAndSettle();
      // 默认 H≈10.47 → snapToHyperfocal 应跳到 10m 档
      await t.tap(find.text('= H'));
      await t.pumpAndSettle();
      // 对焦距离行的 value 文本应包含 "10"
      expect(find.text('10 m'), findsOneWidget);
    });

    testWidgets('切画幅 chip → 弥散圆显示更新', (t) async {
      await t.pumpWidget(_wrap(const CalcPage()));
      await t.pumpAndSettle();
      expect(find.text('0.030 mm'), findsOneWidget);
      await t.tap(find.text('6×6'));
      await t.pumpAndSettle();
      expect(find.text('0.060 mm'), findsOneWidget);
    });
  });
}
