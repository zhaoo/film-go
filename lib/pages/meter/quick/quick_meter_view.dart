import 'dart:math' as math;

import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/widgets/dual_scale.dart';
import 'package:film_go/pages/meter/widgets/measure_icon_button.dart';
import 'package:film_go/pages/meter/widgets/quick_drum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 快速测光视图（PR7）。
///
/// 布局：左侧 [DualScale] 给出曝光对结果，右侧上方是相机预览（暂未接入相机
/// 时显示占位），右下方为锁定按钮。底部是 4 列 [QuickDrum]。
///
/// 注意：相机预览的真正接线（CameraService 启停 + 帧→controller）放在 PR8，
/// 本 PR 只把交互闭环跑通；通过 [preview] 注入可在测试中给一个 SizedBox 占位。
class QuickMeterView extends ConsumerWidget {
  const QuickMeterView({super.key, this.preview});

  final Widget? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(meterControllerProvider);
    final s = c.state;
    final iso = s.shared.iso;

    final liveEv100 = s.quick.lockedEv ?? s.quick.metered?.ev;
    final evEff = liveEv100 == null
        ? null
        : liveEv100 +
            (math.log(iso.value / 100) / math.ln2) -
            s.quick.comp.stops -
            s.quick.filter.stops;
    final pairs = evEff == null
        ? const <ExposurePair>[]
        : EvCalculator.suggestPairs(ev: evEff, iso: iso.value);
    final center = pairs.isEmpty ? 0 : pairs.length ~/ 2;
    final offset = s.quick.userPairOffset ?? 0;
    final activeIndex = pairs.isEmpty
        ? 0
        : (center + offset).clamp(0, pairs.length - 1);

    final ev100Int =
        (liveEv100 ?? 10).round().clamp(QuickDrum.evMin, QuickDrum.evMax);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 64, 12, 12),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: DualScale(
                      pairs: pairs,
                      activeIndex: activeIndex,
                      onIndexChanged: (i) =>
                          c.quickSetPairOffset(i - center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: preview ?? const _PreviewPlaceholder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        MeasureIconButton(
                          locked: s.quick.lockedEv != null,
                          onTap: () {
                            if (s.quick.lockedEv != null) {
                              c.quickUnlock();
                            } else {
                              c.quickLock();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: QuickDrum(
                ev100: ev100Int,
                iso: iso,
                comp: s.quick.comp,
                filter: s.quick.filter,
                onEv100Changed: (v) => c.quickLockTo(v.toDouble()),
                onIsoChanged: c.setIso,
                onCompChanged: c.quickSetComp,
                onFilterChanged: c.quickSetFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.camera_alt_outlined,
          size: 32,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
