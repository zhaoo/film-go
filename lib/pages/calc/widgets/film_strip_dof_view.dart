import 'dart:math' as math;

import 'package:film_go/domain/dof/depth_of_field.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// ∞ 区从右侧 8% 开始；distToX 与 _StripPainter 的 hatch 共用此分界。
const double _kInfZoneStart = 0.92;
const double _kLabelWidth = 56;

/// 顶部胶片卷轴 DoF 可视化。
///
/// 结构（共 160dp）：上齿孔 16 / 中带（自适应剩余）/ 下齿孔 16 / 摘要 32。
class FilmStripDofView extends StatelessWidget {
  const FilmStripDofView({
    super.key,
    required this.result,
    required this.focusMeters,
    this.minDist = 0.3,
    this.maxDist = 1000,
  });

  final DofResult result;
  final double focusMeters;
  final double minDist;
  final double maxDist;

  static String _fmt(double m) {
    if (!m.isFinite) return '∞';
    return m < 10 ? m.toStringAsFixed(1) : m.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final summary = result.farMeters == null
        ? 'H = ${_fmt(result.hyperfocalMeters)}m  ·  总景深 ≈ ∞'
        : 'H = ${_fmt(result.hyperfocalMeters)}m'
            '  ·  总景深 ≈ ${_fmt(result.farMeters! - result.nearMeters)}m';
    return SizedBox(
      height: 160,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _StripPainter(
                          result: result,
                          focusMeters: focusMeters,
                          minDist: minDist,
                          maxDist: maxDist,
                          bandColor: cs.surfaceContainerHighest,
                          dofColor: AppColors.spotHighlight.withOpacity(0.35),
                          markerColor: AppColors.spotHighlight,
                          tickColor: cs.onSurface,
                          outlineColor: cs.outlineVariant,
                        ),
                      ),
                    ),
                    _MarkerLabels(
                      result: result,
                      focusMeters: focusMeters,
                      minDist: minDist,
                      maxDist: maxDist,
                      width: c.maxWidth,
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                summary,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 横轴映射：log scale，超过 maxDist 或 ∞ → 落在 ∞ 区中部。
double distToX(
  double m,
  double width, {
  required double minD,
  required double maxD,
}) {
  final usable = width * _kInfZoneStart;
  if (!m.isFinite || m > maxD) {
    return width - width * (1 - _kInfZoneStart) / 2;
  }
  final clamped = m.clamp(minD, maxD);
  final t = (math.log(clamped) - math.log(minD)) /
      (math.log(maxD) - math.log(minD));
  return t * usable;
}

class _StripPainter extends CustomPainter {
  _StripPainter({
    required this.result,
    required this.focusMeters,
    required this.minDist,
    required this.maxDist,
    required this.bandColor,
    required this.dofColor,
    required this.markerColor,
    required this.tickColor,
    required this.outlineColor,
  });

  final DofResult result;
  final double focusMeters;
  final double minDist;
  final double maxDist;
  final Color bandColor;
  final Color dofColor;
  final Color markerColor;
  final Color tickColor;
  final Color outlineColor;

  static const double _holeRow = 16;
  static const int _holeCount = 24;

  @override
  void paint(Canvas canvas, Size size) {
    // 上下齿孔
    _paintHoles(canvas, size, 0);
    _paintHoles(canvas, size, size.height - _holeRow);

    // 中间带底色
    final mid = Rect.fromLTWH(
      0,
      _holeRow,
      size.width,
      size.height - 2 * _holeRow,
    );
    canvas.drawRect(mid, Paint()..color = bandColor);

    // ∞ 区斜纹（右 8%），与 distToX 共用 _kInfZoneStart
    final infRect = Rect.fromLTRB(
      size.width * _kInfZoneStart,
      _holeRow,
      size.width,
      size.height - _holeRow,
    );
    _paintHatch(canvas, infRect, outlineColor.withOpacity(0.4));

    // DoF 高亮带
    final near = distToX(
      result.nearMeters,
      size.width,
      minD: minDist,
      maxD: maxDist,
    );
    final farRaw = result.farMeters ?? double.infinity;
    final far = distToX(
      farRaw,
      size.width,
      minD: minDist,
      maxD: maxDist,
    );
    if (far > near) {
      final dofRect = Rect.fromLTRB(
        near,
        _holeRow,
        far,
        size.height - _holeRow,
      );
      canvas.drawRect(dofRect, Paint()..color = dofColor);
    }

    // 三条刻度线：near / focus / far
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1;
    final focusX = distToX(
      focusMeters,
      size.width,
      minD: minDist,
      maxD: maxDist,
    );
    final focusPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(near, _holeRow),
      Offset(near, size.height - _holeRow),
      tickPaint,
    );
    canvas.drawLine(
      Offset(focusX, _holeRow),
      Offset(focusX, size.height - _holeRow),
      focusPaint,
    );
    canvas.drawLine(
      Offset(far, _holeRow),
      Offset(far, size.height - _holeRow),
      tickPaint,
    );
  }

  void _paintHoles(Canvas canvas, Size size, double topY) {
    final paint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final spacing = size.width / _holeCount;
    const sq = 8.0;
    final y = topY + (_holeRow - sq) / 2;
    for (var i = 0; i < _holeCount; i++) {
      final x = i * spacing + (spacing - sq) / 2;
      canvas.drawRect(Rect.fromLTWH(x, y, sq, sq), paint);
    }
  }

  void _paintHatch(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(rect);
    const step = 6.0;
    for (var x = rect.left - rect.height; x < rect.right; x += step) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) =>
      old.result != result ||
      old.focusMeters != focusMeters ||
      old.minDist != minDist ||
      old.maxDist != maxDist ||
      old.bandColor != bandColor ||
      old.dofColor != dofColor ||
      old.markerColor != markerColor ||
      old.tickColor != tickColor ||
      old.outlineColor != outlineColor;
}

class _MarkerLabels extends StatelessWidget {
  const _MarkerLabels({
    required this.result,
    required this.focusMeters,
    required this.minDist,
    required this.maxDist,
    required this.width,
  });

  final DofResult result;
  final double focusMeters;
  final double minDist;
  final double maxDist;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final near = distToX(
      result.nearMeters,
      width,
      minD: minDist,
      maxD: maxDist,
    );
    final focusX = distToX(
      focusMeters,
      width,
      minD: minDist,
      maxD: maxDist,
    );
    final farRaw = result.farMeters ?? double.infinity;
    final far = distToX(farRaw, width, minD: minDist, maxD: maxDist);

    final nearLabel = '${FilmStripDofView._fmt(result.nearMeters)}m';
    final focusLabel = focusMeters.isFinite
        ? '${FilmStripDofView._fmt(focusMeters)}m'
        : FilmStripDofView._fmt(focusMeters);
    final farLabel = result.farMeters == null
        ? '∞'
        : '${FilmStripDofView._fmt(result.farMeters!)}m';

    return Stack(
      children: [
        _label(cs, near, nearLabel, '近景深', highlight: false),
        _label(cs, focusX, focusLabel, '对焦点', highlight: true),
        _label(cs, far, farLabel, '远景深', highlight: false),
      ],
    );
  }

  Widget _label(
    ColorScheme cs,
    double x,
    String value,
    String tag, {
    required bool highlight,
  }) {
    final color = highlight ? AppColors.spotHighlight : cs.onSurface;
    final maxLeft = math.max(0.0, width - _kLabelWidth);
    return Positioned(
      left: (x - _kLabelWidth / 2).clamp(0.0, maxLeft),
      bottom: 8,
      width: _kLabelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            tag,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
