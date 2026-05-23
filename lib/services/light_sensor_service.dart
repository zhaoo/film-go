import 'dart:async';
import 'dart:io';

import 'package:light/light.dart';

/// 光线传感器服务（仅 Android）。
class LightSensorService {
  Light? _light;
  StreamSubscription<int>? _sub;
  StreamController<int>? _luxCtrl;

  bool isAvailable() => Platform.isAndroid;

  Stream<int> lux() {
    _luxCtrl ??= StreamController<int>.broadcast();
    if (_sub == null && isAvailable()) {
      _light ??= Light();
      try {
        _sub = _light!.lightSensorStream.listen(
          (v) => _luxCtrl?.add(v),
          onError: (_) {},
        );
      } catch (_) {
        // 设备无 ALS 时插件抛错，吞掉
      }
    }
    return _luxCtrl!.stream;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _luxCtrl?.close();
    _sub = null;
    _luxCtrl = null;
  }
}
