import 'package:film_go/pages/calc/widgets/horizontal_scale.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 一行：label + value + 横向刻度。对焦距离行额外渲染 `= H` chip。
class DofParamRow extends StatelessWidget {
  const DofParamRow({
    super.key,
    required this.label,
    required this.displayValue,
    required this.tickLabels,
    required this.activeIndex,
    required this.onIndexChanged,
    this.onSnapToHyperfocal,
  });

  final String label;
  final String displayValue;
  final List<String> tickLabels;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback? onSnapToHyperfocal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.spotHighlight,
                  ),
                ),
                if (onSnapToHyperfocal != null) ...[
                  const SizedBox(width: 8),
                  _SnapChip(onTap: onSnapToHyperfocal!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          HorizontalScale(
            labels: tickLabels,
            activeIndex: activeIndex,
            onIndexChanged: onIndexChanged,
          ),
        ],
      ),
    );
  }
}

class _SnapChip extends StatelessWidget {
  const _SnapChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.spotHighlight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '= H',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.spotHighlight,
            ),
          ),
        ),
      ),
    );
  }
}
