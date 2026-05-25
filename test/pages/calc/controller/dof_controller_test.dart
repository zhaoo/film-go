import 'package:film_go/domain/dof/film_format.dart';
import 'package:film_go/pages/calc/controller/dof_controller.dart';
import 'package:film_go/pages/calc/controller/dof_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DofState defaults', () {
    const s = DofState.initial;

    test('默认 focusDistIndex=7 → 5m', () {
      expect(s.focusDistIndex, 7);
      expect(s.focusMeters, 5);
    });

    test('默认焦距 50mm、光圈 f/8、画幅 135', () {
      expect(s.focalLengthMm, 50);
      expect(s.aperture.fNumber, 8);
      expect(s.format, FilmFormat.f135);
      expect(s.cocMm, 0.030);
    });

    test('focusSteps 长度 16，首 0.3m、末 ∞', () {
      expect(DofState.focusSteps.length, 16);
      expect(DofState.focusSteps.first, 0.3);
      expect(DofState.focusSteps.last, double.infinity);
    });

    test('默认 result：近景 < 5 < 远景，超焦距 ~10.5m', () {
      final r = s.result;
      expect(r.nearMeters, lessThan(5));
      expect(r.farMeters, isNotNull);
      expect(r.farMeters, greaterThan(5));
      expect(r.hyperfocalMeters, closeTo(10.47, 0.1));
    });

    test('对焦于 ∞ 时 far=null、near=H', () {
      final inf = s.copyWith(focusDistIndex: DofState.focusSteps.length - 1);
      expect(inf.focusMeters, double.infinity);
      expect(inf.result.farMeters, isNull);
      expect(inf.result.nearMeters, closeTo(10.47, 0.1));
    });
  });

  group('DofController', () {
    late DofController c;
    setUp(() => c = DofController());

    test('setFocalLength 更新焦距并刷新 result', () {
      final h0 = c.state.result.hyperfocalMeters;
      c.setFocalLength(100);
      expect(c.state.focalLengthMm, 100);
      expect(c.state.result.hyperfocalMeters, isNot(closeTo(h0, 0.001)));
    });

    test('setApertureIndex 切到 f/16 → 超焦距变小', () {
      final hAt8 = c.state.result.hyperfocalMeters;
      c.setApertureIndex(8); // Aperture.fullStops[8] = f/16
      expect(c.state.aperture.fNumber, 16);
      expect(c.state.result.hyperfocalMeters, lessThan(hAt8));
    });

    test('setFormat 切到 6×6 → 弥散圆变大、超焦距变小', () {
      final h0 = c.state.result.hyperfocalMeters;
      c.setFormat(FilmFormat.f6x6);
      expect(c.state.cocMm, 0.060);
      expect(c.state.result.hyperfocalMeters, lessThan(h0));
    });

    test('snapToHyperfocal: H<100m 时挑最接近档', () {
      // 默认 H ≈ 10.47m → focusSteps 第 9 项 = 10
      c.setFocusDistIndex(0);
      c.snapToHyperfocal();
      expect(DofState.focusSteps[c.state.focusDistIndex], 10);
    });

    test('snapToHyperfocal: H>100m 时跳到 ∞ 档', () {
      // 焦距 200mm + f/2.8 → H ≈ 476m
      c.setFocalLength(200);
      c.setApertureIndex(3); // f/2.8
      c.snapToHyperfocal();
      expect(c.state.focusMeters, double.infinity);
    });

    test('change 调 notifyListeners', () {
      var count = 0;
      c.addListener(() => count++);
      c.setFocalLength(85);
      c.setApertureIndex(4);
      c.setFormat(FilmFormat.f6x7);
      expect(count, 3);
    });
  });
}
