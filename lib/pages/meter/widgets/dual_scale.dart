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
  // 拆为两列各自的同步标志：一列被自动 animate 时只屏蔽该列的
  // onSelectedItemChanged 回调，另一列的用户拖拽仍能被识别。
  bool _leftSyncing = false;
  bool _rightSyncing = false;

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

    // Pending-mount: pairs 由空变非空时，wheels 此刻还没挂载、controllers 没有
    // clients。controllers 是在 initState（pairs 还空、_clampedActive=0）时创建
    // 的，因此 wheels 即将以 initialItem=0 挂载。等帧结束 jumpToItem 到目标位置，
    // 避免轮子卡在 index 0。
    if (!_leftCtrl.hasClients || !_rightCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_leftCtrl.hasClients && _leftCtrl.selectedItem != target) {
          _leftCtrl.jumpToItem(target);
        }
        if (_rightCtrl.hasClients && _rightCtrl.selectedItem != target) {
          _rightCtrl.jumpToItem(target);
        }
      });
      return;
    }

    // 每列独立判断：已经在同步中的列就跳过，避免 _onLeft 触发的右列动画在父层
    // setState 反喂回来时被 didUpdateWidget 再次启动一遍（重复 easing）。
    if (!_leftSyncing && _leftCtrl.selectedItem != target) {
      _leftSyncing = true;
      _leftCtrl
          .animateToItem(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _leftSyncing = false);
    }
    if (!_rightSyncing && _rightCtrl.selectedItem != target) {
      _rightSyncing = true;
      _rightCtrl
          .animateToItem(
            target,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _rightSyncing = false);
    }
  }

  @override
  void dispose() {
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  void _onLeft(int i) {
    // 只有当 LEFT 本身正在被自动 animate 时才忽略；RIGHT 在同步中不应屏蔽
    // 用户对 LEFT 的手动拖拽。
    if (_leftSyncing) return;
    if (i == widget.activeIndex) return;
    widget.onIndexChanged(i);
    if (_rightCtrl.hasClients && _rightCtrl.selectedItem != i) {
      _rightSyncing = true;
      _rightCtrl
          .animateToItem(
            i,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _rightSyncing = false);
    }
  }

  void _onRight(int i) {
    if (_rightSyncing) return;
    if (i == widget.activeIndex) return;
    widget.onIndexChanged(i);
    if (_leftCtrl.hasClients && _leftCtrl.selectedItem != i) {
      _leftSyncing = true;
      _leftCtrl
          .animateToItem(
            i,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          )
          .whenComplete(() => _leftSyncing = false);
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,);
          return Center(child: Text(builder(i), style: style));
        },
      ),
    );
  }
}
