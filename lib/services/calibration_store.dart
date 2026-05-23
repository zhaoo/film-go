import 'package:shared_preferences/shared_preferences.dart';

/// 校准偏移持久化抽象，便于在测试中替换。
abstract interface class CalibrationStoreLike {
  double read();
  Future<void> write(double offset);
  Future<void> clear();
}

/// 持久化测光校准偏移（EV 单位）到 SharedPreferences。
class CalibrationStore implements CalibrationStoreLike {
  CalibrationStore._(this._prefs);

  static const _key = 'meter.calibration.offset.ev';

  final SharedPreferences _prefs;

  static Future<CalibrationStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return CalibrationStore._(prefs);
  }

  @override
  double read() => _prefs.getDouble(_key) ?? 0.0;

  @override
  Future<void> write(double offset) async {
    await _prefs.setDouble(_key, offset);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
