import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:flutter/material.dart';

/// 快速测光左侧的双列竖标尺：左列快门、右列光圈。
///
/// 是结果显示，不接收滚动手势（[IgnorePointer]）。中央高亮行通过
/// [highlightIndex] 指定。
class DualScale extends StatelessWidget {
  const DualScale({
    super.key,
    required this.pairs,
    required this.highlightIndex,
    this.rowHeight = 32,
  });

  final List<ExposurePair> pairs;
  final int highlightIndex;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    if (pairs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('—', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('—', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerY = constraints.maxHeight / 2 - rowHeight / 2;
          final dy = centerY - highlightIndex * rowHeight;
          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: dy,
                child: Column(
                  children: [
                    for (var i = 0; i < pairs.length; i++)
                      _Row(
                        pair: pairs[i],
                        highlight: i == highlightIndex,
                        height: rowHeight,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.pair,
    required this.highlight,
    required this.height,
  });

  final ExposurePair pair;
  final bool highlight;
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    final style = highlight
        ? base?.copyWith(fontWeight: FontWeight.w800)
        : base?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: Center(child: Text(pair.shutter.display, style: style)),
          ),
          Expanded(
            child: Center(child: Text(pair.aperture.display, style: style)),
          ),
        ],
      ),
    );
  }
}
