import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 点测黄框。在父容器内按归一化坐标 [center] (0..1) 定位，56×56。
///
/// 仅在 [visible] = true 时绘制（点测模式开启）。位置变化用 200ms ease 动画。
class SpotOverlay extends StatelessWidget {
  const SpotOverlay({
    super.key,
    required this.center,
    required this.visible,
    this.size = 56,
  });

  final Offset center;
  final bool visible;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.expand();
    }
    return LayoutBuilder(
      builder: (context, c) {
        final left = c.maxWidth * center.dx - size / 2;
        final top = c.maxHeight * center.dy - size / 2;
        return Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: left,
              top: top,
              width: size,
              height: size,
              child: Container(
                key: const ValueKey('spot-frame'),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.spotHighlight, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
