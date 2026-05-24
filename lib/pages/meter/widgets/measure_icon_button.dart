import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 快速测光页右下圆形锁定按钮。
///
/// 未锁定显示空心圆，锁定显示锁。点击触发轻震动 + [onTap]。
class MeasureIconButton extends StatelessWidget {
  const MeasureIconButton({
    super.key,
    required this.locked,
    required this.onTap,
    this.size = 56,
  });

  final bool locked;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = locked ? cs.onPrimary : cs.onSurface;
    final bg = locked ? cs.primary : cs.surfaceContainerHighest;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Icon(
            locked ? Icons.lock_outlined : Icons.radio_button_unchecked,
            size: size * 0.45,
            color: fg,
          ),
        ),
      ),
    );
  }
}
