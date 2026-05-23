import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/widgets/calibration_dialog.dart';
import 'package:film_go/pages/meter/widgets/ev_readout.dart';
import 'package:film_go/pages/meter/widgets/exposure_pair_list.dart';
import 'package:film_go/pages/meter/widgets/iso_selector.dart';
import 'package:film_go/pages/meter/widgets/lock_button.dart';
import 'package:film_go/pages/meter/widgets/manual_ev_dialog.dart';
import 'package:film_go/pages/meter/widgets/meter_dial.dart';
import 'package:film_go/pages/meter/widgets/mode_selector.dart';
import 'package:film_go/pages/meter/widgets/source_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MeterPage extends ConsumerWidget {
  const MeterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(meterControllerProvider);
    final state = c.state;
    final pairs = state.effectiveEv == null
        ? const <ExposurePair>[]
        : EvCalculator.suggestPairs(
            ev: state.effectiveEv!,
            iso: state.iso.value,
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('取景测光'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '校准',
            onPressed: () async {
              final target = await CalibrationDialog.show(context);
              if (target != null) {
                await c.applyCalibrationFromLastReading(targetEv: target);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              MeterDial(ev: state.effectiveEv),
              const SizedBox(height: 8),
              EvReadout(
                ev: state.effectiveEv,
                sourceLabel: state.source.display,
                locked: state.lockedEv != null,
              ),
              const SizedBox(height: 16),
              ExposurePairList(pairs: pairs),
              const SizedBox(height: 16),
              SourceSelector(
                value: state.source,
                sensorAvailable: false,
                onChanged: c.setSource,
              ),
              const SizedBox(height: 12),
              ModeSelector(
                value: state.mode,
                onChanged: c.setMode,
              ),
              const SizedBox(height: 12),
              IsoSelector(
                value: state.iso,
                onChanged: c.setIso,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('手动输入'),
                      onPressed: () async {
                        final v = await ManualEvDialog.show(
                          context,
                          initialEv: state.effectiveEv,
                        );
                        if (v != null) c.setManualEv(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LockButton(
                      locked: state.lockedEv != null,
                      onToggle: () =>
                          state.lockedEv != null ? c.unlock() : c.lock(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
