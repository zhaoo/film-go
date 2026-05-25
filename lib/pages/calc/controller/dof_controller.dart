import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/pages/calc/controller/dof_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DofController extends ChangeNotifier {
  DofController() : _state = DofState.initial;

  DofState _state;
  DofState get state => _state;

  void _set(DofState s) {
    _state = s;
    notifyListeners();
  }

  void setFocusDistIndex(int i) {
    final clamped = i.clamp(0, DofState.focusSteps.length - 1);
    _set(_state.copyWith(focusDistIndex: clamped));
  }

  void setFocalLength(int mm) {
    final clamped = mm.clamp(8, 500);
    _set(_state.copyWith(focalLengthMm: clamped));
  }

  void setApertureIndex(int i) {
    // Aperture.fullStops 长度 13
    final clamped = i.clamp(0, 12);
    _set(_state.copyWith(apertureIndex: clamped));
  }

  void setFormat(FilmFormat f) => _set(_state.copyWith(format: f));

  /// 把对焦距离吸到当前 H 最接近的档；H>100m 直接选 ∞。
  void snapToHyperfocal() {
    final h = _state.result.hyperfocalMeters;
    if (h > 100) {
      _set(
        _state.copyWith(focusDistIndex: DofState.focusSteps.length - 1),
      );
      return;
    }
    var bestIndex = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < DofState.focusSteps.length - 1; i++) {
      final d = (DofState.focusSteps[i] - h).abs();
      if (d < bestDiff) {
        bestDiff = d;
        bestIndex = i;
      }
    }
    _set(_state.copyWith(focusDistIndex: bestIndex));
  }
}

final dofControllerProvider =
    ChangeNotifierProvider<DofController>((ref) => DofController());
