import 'package:film_go/domain/metering/meter_mode.dart';
import 'package:flutter/material.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final MeterMode value;
  final ValueChanged<MeterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MeterMode>(
      segments: [
        for (final m in MeterMode.values)
          ButtonSegment(value: m, label: Text(m.display)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
