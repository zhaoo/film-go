import 'package:film_go/domain/shared/aperture.dart';
import 'package:film_go/pages/calc/controller/dof_controller.dart';
import 'package:film_go/pages/calc/controller/dof_state.dart';
import 'package:film_go/pages/calc/widgets/dof_param_row.dart';
import 'package:film_go/pages/calc/widgets/film_strip_dof_view.dart';
import 'package:film_go/pages/calc/widgets/format_chip_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CalcPage extends ConsumerWidget {
  const CalcPage({super.key});

  static String _fmtFocus(double m) {
    if (!m.isFinite) return '∞';
    return m < 10
        ? '${m.toStringAsFixed(1)} m'
        : '${m.round()} m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(dofControllerProvider);
    final s = c.state;
    return Scaffold(
      appBar: AppBar(title: const Text('景深 · 超焦距')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilmStripDofView(
                result: s.result,
                focusMeters: s.focusMeters,
              ),
            ),
            const Divider(height: 1),
            DofParamRow(
              label: '对焦距离',
              displayValue: _fmtFocus(s.focusMeters),
              tickLabels: [
                for (final v in DofState.focusSteps)
                  if (!v.isFinite)
                    '∞'
                  else if (v == v.truncateToDouble())
                    v.toInt().toString()
                  else
                    v.toStringAsFixed(1),
              ],
              activeIndex: s.focusDistIndex,
              onIndexChanged: c.setFocusDistIndex,
              onSnapToHyperfocal: c.snapToHyperfocal,
            ),
            const Divider(height: 1),
            DofParamRow(
              label: '焦距',
              displayValue: '${s.focalLengthMm} mm',
              tickLabels: [
                for (var mm = 8; mm <= 500; mm++) mm.toString(),
              ],
              activeIndex: s.focalLengthMm - 8,
              onIndexChanged: (i) => c.setFocalLength(i + 8),
            ),
            const Divider(height: 1),
            DofParamRow(
              label: '光圈',
              displayValue: s.aperture.display,
              tickLabels: [
                for (final a in Aperture.fullStops)
                  a.display.replaceFirst('f/', ''),
              ],
              activeIndex: s.apertureIndex,
              onIndexChanged: c.setApertureIndex,
            ),
            const Divider(height: 1),
            _ParamHeader(label: '画幅', value: s.format.label),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: FormatChipRow(
                active: s.format,
                onChanged: c.setFormat,
              ),
            ),
            const Divider(height: 1),
            _CocReadonlyRow(cocMm: s.cocMm),
          ],
        ),
      ),
    );
  }
}

class _ParamHeader extends StatelessWidget {
  const _ParamHeader({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CocReadonlyRow extends StatelessWidget {
  const _CocReadonlyRow({required this.cocMm});
  final double cocMm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('自定义弥散圆 - 即将上线')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(
              '弥散圆 c',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              '${cocMm.toStringAsFixed(3)} mm',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
