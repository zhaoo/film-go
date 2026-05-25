import 'package:film_go/domain/dof/depth_of_field.dart';
import 'package:film_go/pages/calc/widgets/film_strip_dof_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, height: 160, child: child)),
    );

void main() {
  group('FilmStripDofView', () {
    testWidgets('渲染近/对焦/远文字与摘要，far 有限时无 ∞', (t) async {
      const result = DofResult(
        nearMeters: 2.5,
        farMeters: 8.4,
        hyperfocalMeters: 10.47,
      );
      await t.pumpWidget(
        _wrap(
          const FilmStripDofView(
            result: result,
            focusMeters: 5,
          ),
        ),
      );
      expect(find.text('对焦点'), findsOneWidget);
      expect(find.text('近景深'), findsOneWidget);
      expect(find.text('远景深'), findsOneWidget);
      // 摘要含 H
      expect(find.textContaining('H ='), findsOneWidget);
      // ∞ 不应作为远景出现
      expect(find.text('∞'), findsNothing);
    });

    testWidgets('对焦于 ∞ + far=null → 远景显示 ∞、摘要含 ∞', (t) async {
      const result = DofResult(
        nearMeters: 10.47,
        farMeters: null,
        hyperfocalMeters: 10.47,
      );
      await t.pumpWidget(
        _wrap(
          const FilmStripDofView(
            result: result,
            focusMeters: double.infinity,
          ),
        ),
      );
      // 至少有一个 ∞（远景标记 + 可能摘要里再来一个）
      expect(find.text('∞'), findsWidgets);
    });

    testWidgets('< 10m 距离保留 1 位小数，≥ 10m 取整', (t) async {
      const result = DofResult(
        nearMeters: 2.456,
        farMeters: 24.89,
        hyperfocalMeters: 30.0,
      );
      await t.pumpWidget(
        _wrap(
          const FilmStripDofView(
            result: result,
            focusMeters: 8.0,
          ),
        ),
      );
      expect(find.textContaining('2.5'), findsWidgets);
      expect(find.textContaining('25'), findsWidgets);
    });
  });
}
