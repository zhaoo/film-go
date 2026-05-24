import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/pages/meter/pro/pro_meter_view.dart';
import 'package:film_go/pages/meter/quick/quick_meter_view.dart';
import 'package:film_go/pages/meter/widgets/mode_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 测光页骨架：顶部 ModeTab + IndexedStack 持有 Quick / Pro 两个子页面。
///
/// 切换 tab 不重建子页面，相机会话也不重启。
class MeterPage extends ConsumerWidget {
  const MeterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(meterControllerProvider);
    final tab = c.state.currentTab;
    final isPro = tab == MeterTab.pro;
    return Scaffold(
      backgroundColor: isPro ? Colors.black : null,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: tab.index,
                children: const [
                  QuickMeterView(),
                  ProMeterView(),
                ],
              ),
            ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: ModeTab(
                  value: tab,
                  onChanged: c.setTab,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
