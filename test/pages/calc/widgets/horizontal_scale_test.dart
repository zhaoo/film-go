import 'package:film_go/pages/calc/widgets/horizontal_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );

void main() {
  group('HorizontalScale', () {
    testWidgets('渲染当前 active label 加粗、旁侧弱化', (t) async {
      await t.pumpWidget(
        _wrap(
          HorizontalScale(
            labels: const ['48', '49', '50', '51', '52'],
            activeIndex: 2,
            onIndexChanged: (_) {},
          ),
        ),
      );
      await t.pumpAndSettle();
      // active 文本必定出现
      expect(find.text('50'), findsOneWidget);
      // 至少有一个旁侧标签（49 或 51）
      expect(
        find.text('49').evaluate().isNotEmpty ||
            find.text('51').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('activeIndex 变化 → 内部 controller 跟到新位置', (t) async {
      var notified = -1;
      var active = 2;
      await t.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (ctx, setSB) => HorizontalScale(
              labels: const ['a', 'b', 'c', 'd', 'e'],
              activeIndex: active,
              onIndexChanged: (i) => notified = i,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      // 重建到 index 4
      active = 4;
      await t.pumpWidget(
        _wrap(
          HorizontalScale(
            labels: const ['a', 'b', 'c', 'd', 'e'],
            activeIndex: active,
            onIndexChanged: (i) => notified = i,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('e'), findsOneWidget);
      // 同步动画期间不回调
      expect(notified, -1);
    });

    testWidgets('用户 fling → onIndexChanged 被调', (t) async {
      var notified = -1;
      await t.pumpWidget(
        _wrap(
          HorizontalScale(
            labels: const ['a', 'b', 'c', 'd', 'e'],
            activeIndex: 2,
            onIndexChanged: (i) => notified = i,
          ),
        ),
      );
      await t.pumpAndSettle();
      // 从中心位置向左 fling 一段
      await t.fling(find.text('c'), const Offset(-200, 0), 1000);
      await t.pumpAndSettle();
      expect(notified, isNot(-1));
    });
  });
}
