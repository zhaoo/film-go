import 'package:film_go/domain/metering/meter_reading.dart';
import 'package:flutter/material.dart';

class SourceSelector extends StatelessWidget {
  const SourceSelector({
    required this.value,
    required this.onChanged,
    required this.sensorAvailable,
    super.key,
  });

  final MeterSource value;
  final ValueChanged<MeterSource> onChanged;
  final bool sensorAvailable;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MeterSource>(
      segments: [
        for (final s in MeterSource.values)
          ButtonSegment(
            value: s,
            label: Text(s.display),
            enabled: s != MeterSource.lightSensor || sensorAvailable,
          ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
