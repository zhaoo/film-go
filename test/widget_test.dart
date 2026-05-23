import 'package:film_go/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('App 启动后默认进入 Meter Tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FilmGoApp()));
    await tester.pumpAndSettle();

    expect(find.text('取景'), findsOneWidget);
    expect(find.text('计算'), findsOneWidget);
    expect(find.text('胶卷'), findsOneWidget);
    expect(find.text('暗房'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    expect(find.textContaining('Meter'), findsOneWidget);
  });

  testWidgets('点击「计算」Tab 切换到 Calc 页', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FilmGoApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('计算'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Calc'), findsOneWidget);
  });
}
