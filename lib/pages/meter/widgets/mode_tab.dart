import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// 顶部胶囊分段切换：[⚡ 快速 │ 🎯 专业]
class ModeTab extends StatelessWidget {
  const ModeTab({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MeterTab value;
  final ValueChanged<MeterTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            icon: PhosphorIcons.lightning(),
            label: '快速',
            selected: value == MeterTab.quick,
            onTap: () => onChanged(MeterTab.quick),
          ),
          _Segment(
            icon: PhosphorIcons.target(),
            label: '专业',
            selected: value == MeterTab.pro,
            onTap: () => onChanged(MeterTab.pro),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: selected ? cs.onPrimary : cs.onSurface),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
