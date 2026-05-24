import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pro 测光模式循环按钮：spot → centerWeighted → average → spot。
class MeterModeCycleButton extends StatelessWidget {
  const MeterModeCycleButton({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final MeterMode mode;
  final ValueChanged<MeterMode> onChanged;

  static MeterMode _next(MeterMode m) => switch (m) {
        MeterMode.spot => MeterMode.centerWeighted,
        MeterMode.centerWeighted => MeterMode.average,
        MeterMode.average => MeterMode.spot,
      };

  IconData get _icon => switch (mode) {
        MeterMode.spot => Icons.center_focus_strong_outlined,
        MeterMode.centerWeighted => Icons.center_focus_weak_outlined,
        MeterMode.average => Icons.crop_free,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paperWhite.withOpacity(0.12),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onChanged(_next(mode));
        },
        child: SizedBox(
          width: 48,
          height: 48,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _icon,
              key: ValueKey(mode),
              color: AppColors.paperWhite,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
