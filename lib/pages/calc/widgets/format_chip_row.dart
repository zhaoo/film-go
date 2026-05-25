import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 4 个画幅 chip 平铺单选。选中：spotHighlight 底 + charcoal 字。
class FormatChipRow extends StatelessWidget {
  const FormatChipRow({
    super.key,
    required this.active,
    required this.onChanged,
  });

  final FilmFormat active;
  final ValueChanged<FilmFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final f in FilmFormat.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _Chip(
                label: f.label,
                selected: f == active,
                onTap: () {
                  if (f == active) return;
                  onChanged(f);
                },
                cs: cs,
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.spotHighlight : cs.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                color: selected
                    ? AppColors.charcoalBlack
                    : cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
