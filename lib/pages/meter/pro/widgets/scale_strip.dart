import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

const double _itemWidth = 64.0;

/// Pro 底部刻度尺：上行 f 值，下行快门。中央那一档（highlightIndex）加粗 + 黄底；
/// 整条随 highlightIndex 居中平移（200ms ease）。
class ScaleStrip extends StatelessWidget {
  const ScaleStrip({
    super.key,
    required this.pairs,
    required this.highlightIndex,
  });

  final List<ExposurePair> pairs;
  final int highlightIndex;

  @override
  Widget build(BuildContext context) {
    if (pairs.isEmpty) {
      return const _EmptyPlaceholder();
    }
    return LayoutBuilder(
      builder: (context, c) {
        final centerX = c.maxWidth / 2;
        final highlightCenter = highlightIndex * _itemWidth + _itemWidth / 2;
        final dx = centerX - highlightCenter;
        return ClipRect(
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: dx,
                top: 0,
                bottom: 0,
                width: pairs.length * _itemWidth,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < pairs.length; i++)
                      _ScaleColumn(
                        pair: pairs[i],
                        highlight: i == highlightIndex,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: AppColors.paperWhite.withOpacity(0.60),
      fontSize: 14,
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('—', style: style),
          const SizedBox(height: 4),
          Text('—', style: style),
        ],
      ),
    );
  }
}

class _ScaleColumn extends StatelessWidget {
  const _ScaleColumn({required this.pair, required this.highlight});
  final ExposurePair pair;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? AppColors.spotHighlight
        : AppColors.paperWhite.withOpacity(0.70);
    final weight = highlight ? FontWeight.w800 : FontWeight.w500;
    final style = TextStyle(
      color: color,
      fontSize: 14,
      fontWeight: weight,
      height: 1.2,
    );
    const strut = StrutStyle(fontSize: 14, height: 1.2, forceStrutHeight: true);
    return SizedBox(
      width: _itemWidth,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pair.aperture.display, style: style, strutStyle: strut),
            const SizedBox(height: 4),
            Text(pair.shutter.display, style: style, strutStyle: strut),
          ],
        ),
      ),
    );
  }
}
