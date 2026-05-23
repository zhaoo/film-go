import 'dart:async';

import 'package:camera/camera.dart' show CameraPreview;
import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/domain/metering/meter_reading.dart';
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
import 'package:film_go/services/camera_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class MeterPage extends ConsumerStatefulWidget {
  const MeterPage({super.key});

  @override
  ConsumerState<MeterPage> createState() => _MeterPageState();
}

class _MeterPageState extends ConsumerState<MeterPage> {
  CameraService? _camera;
  StreamSubscription<GrayFrame>? _frameSub;
  MeterSource? _wiredSource;

  @override
  void dispose() {
    _frameSub?.cancel();
    unawaited(_camera?.dispose());
    super.dispose();
  }

  Future<void> _wireCamera() async {
    if (_camera != null) return;
    final granted = await Permission.camera.request().isGranted;
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未授予相机权限，已退回手动模式')),
        );
        ref.read(meterControllerProvider).setSource(MeterSource.manual);
      }
      return;
    }
    final svc = CameraService();
    try {
      await svc.initialize();
      await svc.start();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机初始化失败：$e')),
        );
        ref.read(meterControllerProvider).setSource(MeterSource.manual);
      }
      await svc.dispose();
      return;
    }
    _camera = svc;
    _frameSub = svc.frames().listen((frame) {
      ref.read(meterControllerProvider).processCameraFrame(frame);
    });
    if (mounted) setState(() {});
  }

  Future<void> _unwireCamera() async {
    await _frameSub?.cancel();
    _frameSub = null;
    await _camera?.dispose();
    _camera = null;
    if (mounted) setState(() {});
  }

  Future<void> _onSourceChanged(MeterSource s) async {
    ref.read(meterControllerProvider).setSource(s);
    if (s == MeterSource.camera) {
      await _wireCamera();
    } else {
      await _unwireCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(meterControllerProvider);
    final state = c.state;
    if (_wiredSource != state.source) {
      _wiredSource = state.source;
    }
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
              if (state.source == MeterSource.camera &&
                  _camera?.controller?.value.isInitialized == true)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: CameraPreview(_camera!.controller!),
                )
              else
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
                sensorAvailable:
                    defaultTargetPlatform == TargetPlatform.android,
                onChanged: _onSourceChanged,
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
