import 'package:film_go/domain/metering/luminance_to_ev.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LuminanceToEv.fromGrayMean', () {
    test('ISO 翻倍等价于 EV +1', () {
      final atIso100 = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: IsoValue(100),
        calibrationOffset: 0,
      );
      final atIso200 = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: IsoValue(200),
        calibrationOffset: 0,
      );
      expect(atIso200 - atIso100, closeTo(1.0, 1e-9));
    });

    test('grayMean 翻倍等价于 EV +1', () {
      final atDim = LuminanceToEv.fromGrayMean(
        grayMean: 64,
        iso: IsoValue(100),
        calibrationOffset: 0,
      );
      final atBright = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: IsoValue(100),
        calibrationOffset: 0,
      );
      expect(atBright - atDim, closeTo(1.0, 1e-9));
    });

    test('校准偏移直接加到结果上', () {
      final base = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: IsoValue(100),
        calibrationOffset: 0,
      );
      final tuned = LuminanceToEv.fromGrayMean(
        grayMean: 128,
        iso: IsoValue(100),
        calibrationOffset: 1.5,
      );
      expect(tuned - base, closeTo(1.5, 1e-9));
    });

    test('grayMean=0 安全返回低值（不抛 NaN）', () {
      final v = LuminanceToEv.fromGrayMean(
        grayMean: 0,
        iso: IsoValue(100),
        calibrationOffset: 0,
      );
      expect(v.isFinite, isTrue);
      expect(v, lessThan(-5), reason: '完全黑应给一个非常低的 EV');
    });
  });

  group('LuminanceToEv.calibrationOffsetFor', () {
    test('给定 grayMean/ISO 与目标 EV，反推偏移使结果对齐', () {
      final iso = IsoValue(100);
      const grayMean = 128;
      const targetEv = 12.0;
      final offset = LuminanceToEv.calibrationOffsetFor(
        grayMean: grayMean,
        iso: iso,
        targetEv: targetEv,
      );
      final ev = LuminanceToEv.fromGrayMean(
        grayMean: grayMean,
        iso: iso,
        calibrationOffset: offset,
      );
      expect(ev, closeTo(targetEv, 1e-6));
    });
  });
}
