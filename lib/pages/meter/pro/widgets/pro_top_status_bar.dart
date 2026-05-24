import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Pro 顶部状态栏：左 `ISO 400`，右 `EV: -1/3`。
///
/// 由 [ProMeterView] 直接放在 SafeArea 顶部，预留中间给 [ModeTab] 浮顶。
class ProTopStatusBar extends StatelessWidget {
  const ProTopStatusBar({
    super.key,
    required this.iso,
    required this.comp,
  });

  final IsoValue iso;
  final EvStop comp;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.paperWhite,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('ISO ${iso.value}', style: style),
          Text('EV: ${comp.display}', style: style),
        ],
      ),
    );
  }
}
