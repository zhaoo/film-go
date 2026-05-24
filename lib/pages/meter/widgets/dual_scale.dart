import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:flutter/material.dart';

/// 快速测光左侧的双列竖滚轮：左列快门、右列光圈。
///
/// 两列共享同一个 index 空间（pairs 的索引）。任一列滚动会触发
/// [onIndexChanged] 并把另一列以动画同步到同一 index；父层把 [activeIndex]
/// 重新喂回来时两列都 animate 到该位置。
class DualScale extends StatefulWidget {
  const DualScale({
    super.key,
    required this.pairs,
    required this.activeIndex,
    required this.onIndexChanged,
    this.itemExtent = 32,
  });

  final List<ExposurePair> pairs;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final double itemExtent;

  @override
  State<DualScale> createState() => _DualScaleState();
}

class _DualScaleState extends State<DualScale> {
  late FixedExtentScrollController _leftCtrl;
  late FixedExtentScrollController _rightCtrl;
  bool _syncing = false;

  int get _clampedActive {
    if (widget.pairs.isEmpty) return 0;
    return widget.activeIndex.clamp(0, widget.pairs.length - 1);
  }

  @override
  void initState() {
    super.initState();
    _leftCtrl = FixedExtentScrollController(initialItem: _clampedActive);
    _rightCtrl = FixedExtentScrollController(initialItem: _clampedActive);
  }

  @override
  void didUpdateWidget(covariant DualScale old) {
    super.didUpdateWidget(old);
    if (widget.pairs.isEmpty) return;
    final target = _clampedActive;
    final futures = <Future<void>>[];
    if (_leftCtrl.hasClients && _leftCtrl.selectedItem != target) {
      futures.add(_leftCtrl.animateToItem(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ));
    }
    if (_rightCtrl.hasClients && _rightCtrl.selectedItem != target) {
      futures.add(_rightCtrl.animateToItem(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ));
    }
    if (futures.isNotEmpty) {
      _syncing = true;
      Future.wait(futures).whenComplete(() => _syncing = false);
    }
  }

  @override
  void dispose() {
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  void _onLeft(int i) => _onAny(i, other: _rightCtrl);
  void _onRight(int i) => _onAny(i, other: _leftCtrl);

  void _onAny(int i, {required FixedExtentScrollController other}) {
    if (_syncing) return;
    if (i == widget.activeIndex) return;
    widget.onIndexChanged(i);
    if (other.hasClients && other.selectedItem != i) {
      _syncing = true;
      other
          .animateToItem(
            i,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pairs.isEmpty) {
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
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                height: widget.itemExtent,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _Wheel(
                controller: _leftCtrl,
                itemExtent: widget.itemExtent,
                count: widget.pairs.length,
                builder: (i) => widget.pairs[i].shutter.display,
                onChanged: _onLeft,
                activeIndex: _clampedActive,
              ),
            ),
            Expanded(
              child: _Wheel(
                controller: _rightCtrl,
                itemExtent: widget.itemExtent,
                count: widget.pairs.length,
                builder: (i) => widget.pairs[i].aperture.display,
                onChanged: _onRight,
                activeIndex: _clampedActive,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.itemExtent,
    required this.count,
    required this.builder,
    required this.onChanged,
    required this.activeIndex,
  });

  final FixedExtentScrollController controller;
  final double itemExtent;
  final int count;
  final String Function(int) builder;
  final ValueChanged<int> onChanged;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      perspective: 0.001,
      diameterRatio: 100,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, i) {
          final highlight = i == activeIndex;
          final style = highlight
              ? base?.copyWith(fontWeight: FontWeight.w800)
              : base?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant);
          return Center(child: Text(builder(i), style: style));
        },
      ),
    );
  }
}
