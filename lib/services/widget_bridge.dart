import 'package:film_go/pages/meter/controller/meter_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 把 MeterController 的 ISO / 校准变化单向同步到 SharedPreferences，
/// 供桌面小部件（Android）读取。Widget 端不通过 FlutterEngine，因此用
/// SharedPreferences 作为唯一跨进程通道。
class WidgetBridge {
  WidgetBridge({required this.prefs});

  final SharedPreferences prefs;

  static const keyIso = 'widget.iso';
  static const keyCalOffset = 'widget.calOffset';

  MeterController? _controller;
  late void Function() _listener;

  void attach(MeterController controller) {
    assert(_controller == null, 'WidgetBridge.attach() called twice without detach()');
    _controller = controller;
    _listener = () => _sync(controller);
    controller.addListener(_listener);
    _sync(controller);
  }

  void detach() {
    _controller?.removeListener(_listener);
    _controller = null;
  }

  int _lastIso = -1;
  // Sentinel: NaN != anything (including itself), so the first compare in
  // _sync always triggers an initial write.
  double _lastOffset = double.nan;

  void _sync(MeterController c) {
    final iso = c.state.shared.iso.value;
    final off = c.state.shared.calibrationOffset;
    if (iso != _lastIso) {
      prefs.setInt(keyIso, iso);
      _lastIso = iso;
    }
    if (off != _lastOffset) {
      prefs.setDouble(keyCalOffset, off);
      _lastOffset = off;
    }
  }
}
