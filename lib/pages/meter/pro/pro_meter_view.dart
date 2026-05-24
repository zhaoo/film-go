import 'dart:math' as math;

import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/pro/widgets/meter_mode_cycle_button.dart';
import 'package:film_go/pages/meter/pro/widgets/pro_preview_layer.dart';
import 'package:film_go/pages/meter/pro/widgets/pro_readout.dart';
import 'package:film_go/pages/meter/pro/widgets/pro_top_status_bar.dart';
import 'package:film_go/pages/meter/pro/widgets/scale_strip.dart';
import 'package:film_go/pages/meter/pro/widgets/shutter_button.dart';
import 'package:film_go/pages/meter/pro/widgets/spot_overlay.dart';
import 'package:film_go/services/camera_capture_service.dart';
import 'package:film_go/services/watermark_renderer.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pro 测光页：全屏取景 + 顶部状态栏 + 底部刻度尺 + 左下读数 + 右下模式按钮 + 中央快门。
///
/// 通过 [preview] 注入相机预览以便测试；[captureService] 也可注入。
class ProMeterView extends ConsumerStatefulWidget {
  const ProMeterView({
    super.key,
    this.preview,
    this.captureService,
  });

  final Widget? preview;
  final CameraCaptureService? captureService;

  @override
  ConsumerState<ProMeterView> createState() => _ProMeterViewState();
}

class _ProMeterViewState extends ConsumerState<ProMeterView> {
  bool _capturing = false;

  Future<void> _onShutter(ExposurePair? pair) async {
    final svc = widget.captureService;
    if (svc == null || pair == null) return;
    setState(() => _capturing = true);
    try {
      final c = ref.read(meterControllerProvider);
      await svc.captureWithWatermark(
        WatermarkData(
          iso: 'ISO ${c.state.shared.iso.value}',
          shutter: pair.shutter.display,
          aperture: pair.aperture.display,
          timestamp: DateTime.now(),
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(meterControllerProvider);
    final s = c.state;
    final iso = s.shared.iso;
    final ev100 = s.pro.metered?.ev;
    final evEff = ev100 == null
        ? null
        : ev100 +
            (math.log(iso.value / 100) / math.ln2) -
            s.pro.comp.stops -
            s.pro.filter.stops;
    final pairs = evEff == null
        ? const <ExposurePair>[]
        : EvCalculator.suggestPairs(ev: evEff, iso: iso.value);
    final highlightIndex = pairs.isEmpty ? 0 : pairs.length ~/ 2;
    final mainPair = pairs.isEmpty ? null : pairs[highlightIndex];

    return Stack(
      fit: StackFit.expand,
      children: [
        // 全屏预览 + 点击设置 spot 中心
        Positioned.fill(
          child: ProPreviewLayer(
            onTapNormalized: (o) {
              c.proSetSpotCenter(o);
            },
            child: widget.preview ?? const _PreviewPlaceholder(),
          ),
        ),
        // 点测黄框（仅 spot 模式可见）
        Positioned.fill(
          child: IgnorePointer(
            child: SpotOverlay(
              center: s.pro.spotCenter,
              visible: s.pro.meterMode == MeterMode.spot,
            ),
          ),
        ),
        // 顶部状态栏（让出 ModeTab 居中区域）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ProTopStatusBar(iso: iso, comp: s.pro.comp),
        ),
        // 底部刻度尺
        Positioned(
          left: 0,
          right: 0,
          bottom: 140,
          height: 72,
          child: ScaleStrip(pairs: pairs, highlightIndex: highlightIndex),
        ),
        // 左下读数
        Positioned(
          left: 8,
          bottom: 28,
          child: ProReadout(pair: mainPair),
        ),
        // 中央快门
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Center(
            child: ShutterButton(
              busy: _capturing,
              onTap: () => _onShutter(mainPair),
            ),
          ),
        ),
        // 右下模式循环
        Positioned(
          right: 16,
          bottom: 36,
          child: MeterModeCycleButton(
            mode: s.pro.meterMode,
            onChanged: c.proSetMeterMode,
          ),
        ),
      ],
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.charcoalBlack,
      child: Center(
        child: Icon(
          Icons.camera_alt_outlined,
          size: 48,
          color: AppColors.paperWhite.withOpacity(0.24),
        ),
      ),
    );
  }
}
