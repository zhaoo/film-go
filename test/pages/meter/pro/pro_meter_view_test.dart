import 'dart:typed_data';

import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/pages/meter/pro/pro_meter_view.dart';
import 'package:film_go/pages/meter/pro/widgets/meter_mode_cycle_button.dart';
import 'package:film_go/pages/meter/pro/widgets/pro_top_status_bar.dart';
import 'package:film_go/pages/meter/pro/widgets/scale_strip.dart';
import 'package:film_go/pages/meter/pro/widgets/shutter_button.dart';
import 'package:film_go/pages/meter/pro/widgets/spot_overlay.dart';
import 'package:film_go/services/calibration_store.dart';
import 'package:film_go/services/camera_capture_service.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:film_go/services/watermark_renderer.dart';
import 'package:film_go/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _Store implements CalibrationStoreLike {
  @override
  double read() => 0;
  @override
  Future<void> write(double v) async {}
  @override
  Future<void> clear() async {}
}

class _SpyCapture extends CameraCaptureService {
  _SpyCapture(this.records)
      : super(
          capture: () async => Uint8List(0),
          saveToGallery: (b, n) async {},
          useIsolate: false,
        );

  final List<WatermarkData> records;

  @override
  Future<void> captureWithWatermark(WatermarkData data) async {
    records.add(data);
  }
}

Widget _wrap(MeterController c, {CameraCaptureService? svc}) => ProviderScope(
      overrides: [
        meterControllerProvider.overrideWith((ref) => c),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ProMeterView(
            preview: const SizedBox.shrink(),
            captureService: svc,
          ),
        ),
      ),
    );

GrayFrame _solid(int w, int h, int v) {
  final b = Uint8List(w * h);
  for (var i = 0; i < b.length; i++) {
    b[i] = v;
  }
  return GrayFrame(bytes: b, width: w, height: h, bytesPerRow: w);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('Pro 视图：渲染状态栏 + ScaleStrip + 模式按钮 + 快门', (tester) async {
    final c = MeterController(store: _Store())..bootstrap();
    c.setTab(MeterTab.pro);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    expect(find.byType(ProTopStatusBar), findsOneWidget);
    expect(find.byType(ScaleStrip), findsOneWidget);
    expect(find.byType(ShutterButton), findsOneWidget);
    expect(find.byType(MeterModeCycleButton), findsOneWidget);
    expect(find.byType(SpotOverlay), findsOneWidget);
    expect(find.text('ISO 400'), findsOneWidget);
  });

  testWidgets('点击 MeterModeCycleButton 切换 pro 测光模式', (tester) async {
    final c = MeterController(store: _Store())..bootstrap();
    c.setTab(MeterTab.pro);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();

    expect(c.state.pro.meterMode, MeterMode.centerWeighted);
    await tester.tap(find.byType(MeterModeCycleButton));
    await tester.pumpAndSettle();
    expect(c.state.pro.meterMode, MeterMode.average);
  });

  testWidgets('快门点击：有读数时调用 captureService 并传 ISO/快门/光圈', (tester) async {
    final records = <WatermarkData>[];
    final svc = _SpyCapture(records);

    final c = MeterController(store: _Store())..bootstrap();
    c.setTab(MeterTab.pro);
    c.processCameraFrame(_solid(20, 20, 200));

    await tester.pumpWidget(_wrap(c, svc: svc));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ShutterButton));
    await tester.pumpAndSettle();

    expect(records, isNotEmpty);
    expect(records.first.iso, 'ISO 400');
    expect(records.first.shutter, isNotEmpty);
    expect(records.first.aperture, startsWith('f/'));
  });
}
