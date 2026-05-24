import 'dart:async';

import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pro 圆形快门按钮：白底 + 内圈描边；按下出动画；忙碌时显示进度圈。
class ShutterButton extends StatefulWidget {
  const ShutterButton({
    super.key,
    required this.onTap,
    this.busy = false,
    this.size = 72,
  });

  final VoidCallback onTap;
  final bool busy;
  final double size;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  double _scale = 1;

  void _press() async {
    if (widget.busy) return;
    unawaited(HapticFeedback.heavyImpact());
    setState(() => _scale = 0.92);
    widget.onTap();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _scale = 1);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _press,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 80),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.paperWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.paperWhite, width: 3),
                ),
              ),
              Container(
                width: size - 12,
                height: size - 12,
                decoration: const BoxDecoration(
                  color: AppColors.paperWhite,
                  shape: BoxShape.circle,
                ),
              ),
              if (widget.busy)
                SizedBox(
                  width: size - 16,
                  height: size - 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.charcoalBlack.withOpacity(0.54),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
