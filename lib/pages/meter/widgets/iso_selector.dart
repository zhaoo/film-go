import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter/material.dart';

class IsoSelector extends StatelessWidget {
  const IsoSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IsoValue value;
  final ValueChanged<IsoValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final iso in IsoValue.fullStops)
          ChoiceChip(
            label: Text(iso.value.toString()),
            selected: iso == value,
            onSelected: (s) {
              if (s) onChanged(iso);
            },
          ),
      ],
    );
  }
}
