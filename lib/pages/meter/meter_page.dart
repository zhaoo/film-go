import 'dart:async';

import 'package:camera/camera.dart';
import 'package:film_go/domain/metering/luminance_extractor.dart';
import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:film_go/pages/meter/controller/meter_state.dart';
import 'package:film_go/pages/meter/pro/pro_meter_view.dart';
import 'package:film_go/pages/meter/quick/quick_meter_view.dart';
import 'package:film_go/pages/meter/widgets/mode_tab.dart';
import 'package:film_go/services/camera_capture_service.dart';
import 'package:film_go/services/camera_metadata_channel.dart';
import 'package:film_go/services/camera_service.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 测光页骨架 + 相机/metadata 生命周期。
///
/// initState 拉起 [CameraService] + [CameraMetadataChannel]，把帧 / metadata 推
/// 到 [MeterController]；dispose 时清理。Quick / Pro 子页通过 [IndexedStack]
/// 持有，切换 tab 不重建相机会话。
class MeterPage extends ConsumerStatefulWidget {
  const MeterPage({super.key});

  @override
  ConsumerState<MeterPage> createState() => _MeterPageState();
}

class _MeterPageState extends ConsumerState<MeterPage> {
  final CameraService _camera = CameraService();
  final CameraMetadataChannel _metadata = CameraMetadataChannel();
  CameraCaptureService? _capture;
  StreamSubscription<GrayFrame>? _framesSub;
  StreamSubscription<CameraMetadataFrame>? _metaSub;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _camera.initialize();
      await _camera.start();
      _framesSub = _camera.frames().listen(_onFrame);

      // metadata：先查支持再开订阅。
      final supported = await _metadata.isSupported();
      ref.read(meterControllerProvider).setMetadataSupported(supported);
      if (supported) {
        _metaSub = _metadata.frames().listen(_onMeta);
      }

      _capture = CameraCaptureService(
        capture: () async {
          final controller = _camera.controller;
          if (controller == null) {
            throw StateError('相机未初始化');
          }
          final file = await controller.takePicture();
          return Uint8List.fromList(await file.readAsBytes());
        },
        saveToGallery: (bytes, name) async {
          // image_gallery_saver 在 PR5 已加入依赖；此处占位，真机集成时
          // 由 platform-specific MediaStore / PhotoKit 通道接管。
        },
      );
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // 相机不可用（模拟器、权限拒绝等）：保持降级显示，不抛出。
      if (mounted) setState(() => _ready = false);
    }
  }

  void _onFrame(GrayFrame f) {
    final format = defaultTargetPlatform == TargetPlatform.iOS
        ? LumaFormat.fullRange
        : LumaFormat.yuvLimited;
    ref.read(meterControllerProvider).processCameraFrame(f, format: format);
  }

  void _onMeta(CameraMetadataFrame m) {
    ref.read(meterControllerProvider).processCameraMetadata(m);
  }

  @override
  void dispose() {
    _framesSub?.cancel();
    _metaSub?.cancel();
    _camera.dispose();
    super.dispose();
  }

  Widget? _buildPreview() {
    if (!_ready) return null;
    final controller = _camera.controller;
    if (controller == null || !controller.value.isInitialized) return null;
    return CameraPreview(controller);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(meterControllerProvider);
    final tab = c.state.currentTab;
    final isPro = tab == MeterTab.pro;
    final preview = _buildPreview();
    return Scaffold(
      backgroundColor: isPro ? AppColors.charcoalBlack : null,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: tab.index,
                children: [
                  QuickMeterView(preview: preview),
                  ProMeterView(preview: preview, captureService: _capture),
                ],
              ),
            ),
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: ModeTab(
                  value: tab,
                  onChanged: c.setTab,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
