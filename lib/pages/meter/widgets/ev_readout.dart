import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

class EvReadout extends StatelessWidget {
  const EvReadout({
    required this.ev,
    required this.sourceLabel,
    this.locked = false,
    super.key,
  });

  final double? ev;
  final String sourceLabel;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final value = ev?.toStringAsFixed(1) ?? '--';
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'EV $value',
          style: tt.displayMedium?.copyWith(
            fontWeight: FontWeight.w300,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sourceLabel,
              style: tt.labelMedium?.copyWith(color: AppColors.gray500),
            ),
            if (locked) ...[
              const SizedBox(width: 8),
              const Icon(Icons.lock, size: 14, color: AppColors.gray500),
            ],
          ],
        ),
      ],
    );
  }
}
