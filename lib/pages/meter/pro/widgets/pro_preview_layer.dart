import 'package:flutter/material.dart';

/// Pro 全屏预览层：把传入的 [child]（一般是 `CameraPreview` 或测试占位）铺满，
/// 并把指针落点转成预览归一化坐标 (0..1) 通过 [onTapNormalized] 抛出。
class ProPreviewLayer extends StatelessWidget {
  const ProPreviewLayer({
    super.key,
    required this.child,
    required this.onTapNormalized,
  });

  final Widget child;
  final ValueChanged<Offset> onTapNormalized;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            if (c.maxWidth <= 0 || c.maxHeight <= 0) return;
            final dx = (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0);
            final dy = (d.localPosition.dy / c.maxHeight).clamp(0.0, 1.0);
            onTapNormalized(Offset(dx, dy));
          },
          child: SizedBox.expand(child: child),
        );
      },
    );
  }
}
