import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/pages/calc/widgets/format_chip_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FormatChipRow', () {
    testWidgets('渲染 4 个 label', (t) async {
      await t.pumpWidget(
        _wrap(
          FormatChipRow(
            active: FilmFormat.f135,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('135'), findsOneWidget);
      expect(find.text('6×6'), findsOneWidget);
      expect(find.text('6×7'), findsOneWidget);
      expect(find.text('4×5'), findsOneWidget);
    });

    testWidgets('点未选中的 chip 触发 onChanged', (t) async {
      FilmFormat? picked;
      await t.pumpWidget(
        _wrap(
          FormatChipRow(
            active: FilmFormat.f135,
            onChanged: (f) => picked = f,
          ),
        ),
      );
      await t.tap(find.text('6×7'));
      expect(picked, FilmFormat.f6x7);
    });

    testWidgets('点已选中 chip 不重复触发', (t) async {
      var count = 0;
      await t.pumpWidget(
        _wrap(
          FormatChipRow(
            active: FilmFormat.f135,
            onChanged: (_) => count++,
          ),
        ),
      );
      await t.tap(find.text('135'));
      expect(count, 0);
    });
  });
}
