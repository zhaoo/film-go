import 'dart:math' as math;

import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

class MeterDial extends StatelessWidget {
  const MeterDial({required this.ev, super.key});

  final double? ev;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: const Size.square(220),
      painter: _DialPainter(
        ev: ev,
        fg: isDark ? AppColors.white : AppColors.black,
        muted: AppColors.gray500,
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.ev, required this.fg, required this.muted});
  final double? ev;
  final Color fg;
  final Color muted;

  static const double _minEv = -3;
  static const double _maxEv = 18;
  static const double _arc = math.pi * 5 / 3;

  double _angleFor(double ev) {
    final t = ((ev - _minEv) / (_maxEv - _minEv)).clamp(0.0, 1.0);
    return -_arc / 2 + t * _arc - math.pi / 2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;

    final ringPaint = Paint()
      ..color = muted.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, r, ringPaint);

    for (var v = _minEv.toInt(); v <= _maxEv.toInt(); v++) {
      final a = _angleFor(v.toDouble());
      final outer = Offset(
        center.dx + r * math.cos(a),
        center.dy + r * math.sin(a),
      );
      final inner = Offset(
        center.dx + (r - (v % 5 == 0 ? 14 : 8)) * math.cos(a),
        center.dy + (r - (v % 5 == 0 ? 14 : 8)) * math.sin(a),
      );
      final p = Paint()
        ..color = v % 5 == 0 ? fg : muted
        ..strokeWidth = v % 5 == 0 ? 2 : 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(inner, outer, p);
      if (v % 5 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$v',
            style: TextStyle(color: fg, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final lp = Offset(
          center.dx + (r - 24) * math.cos(a) - tp.width / 2,
          center.dy + (r - 24) * math.sin(a) - tp.height / 2,
        );
        tp.paint(canvas, lp);
      }
    }

    final v = ev;
    if (v != null) {
      final a = _angleFor(v);
      final tip = Offset(
        center.dx + (r - 4) * math.cos(a),
        center.dy + (r - 4) * math.sin(a),
      );
      final p = Paint()
        ..color = fg
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center, tip, p);
      canvas.drawCircle(center, 4, p..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.ev != ev;
}
