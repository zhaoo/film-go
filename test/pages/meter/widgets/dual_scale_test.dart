import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/domain/shared/shutter_speed.dart';
import 'package:film_go/pages/meter/widgets/dual_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<ExposurePair> _pairs() => [
      ExposurePair(aperture: Aperture(2.0), shutter: ShutterSpeed.seconds(1 / 500)),
      ExposurePair(aperture: Aperture(2.8), shutter: ShutterSpeed.seconds(1 / 250)),
      ExposurePair(aperture: Aperture(4.0), shutter: ShutterSpeed.seconds(1 / 125)),
      ExposurePair(aperture: Aperture(5.6), shutter: ShutterSpeed.seconds(1 / 60)),
      ExposurePair(aperture: Aperture(8.0), shutter: ShutterSpeed.seconds(1 / 30)),
    ];

Widget _host({
  required List<ExposurePair> pairs,
  required int activeIndex,
  required ValueChanged<int> onIndexChanged,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 320,
          child: DualScale(
            pairs: pairs,
            activeIndex: activeIndex,
            onIndexChanged: onIndexChanged,
          ),
        ),
      ),
    );

void main() {
  testWidgets('渲染时中心档可见（带 highlight 文本）', (tester) async {
    await tester.pumpWidget(_host(
      pairs: _pairs(),
      activeIndex: 2,
      onIndexChanged: (_) {},
    ));
    await tester.pumpAndSettle();
    expect(find.text('1/125'), findsOneWidget);
    expect(find.text('f/4'), findsOneWidget);
  });

  testWidgets('pairs 为空时显示占位 —', (tester) async {
    await tester.pumpWidget(_host(
      pairs: const [],
      activeIndex: 0,
      onIndexChanged: (_) {},
    ));
    expect(find.text('—'), findsWidgets);
  });

  testWidgets('外部传入新 activeIndex 时两列都 animate 过去', (tester) async {
    final pairs = _pairs();
    int active = 2;
    late StateSetter setter;
    await tester.pumpWidget(StatefulBuilder(
      builder: (ctx, setState) {
        setter = setState;
        return _host(
          pairs: pairs,
          activeIndex: active,
          onIndexChanged: (_) {},
        );
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('1/125'), findsOneWidget);

    setter(() => active = 0);
    await tester.pumpAndSettle();
    expect(find.text('1/500'), findsOneWidget);
    expect(find.text('f/2'), findsOneWidget);
  });

  testWidgets('滚动左列触发 onIndexChanged，并把右列同步滚到该 index',
      (tester) async {
    final pairs = _pairs();
    final notifications = <int>[];
    await tester.pumpWidget(_host(
      pairs: pairs,
      activeIndex: 2,
      onIndexChanged: notifications.add,
    ));
    await tester.pumpAndSettle();

    // 两列 ListWheelScrollView，深度优先遍历下左列在 first。
    final wheels = find.byType(ListWheelScrollView);
    expect(wheels, findsNWidgets(2));

    // 上滑（手指上移）= 列表往后翻 = index 增加
    await tester.drag(wheels.first, const Offset(0, -64));
    await tester.pumpAndSettle();

    expect(notifications, isNotEmpty);
    expect(notifications.last, greaterThan(2));
  });
}
