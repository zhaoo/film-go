import 'package:film_go/domain/shared/ev_stop.dart';
import 'package:film_go/domain/shared/iso_value.dart';
import 'package:film_go/domain/shared/nd_filter.dart';
import 'package:flutter/material.dart';

const _itemExtent = 40.0;

/// 4 列滚轮：EV100 / ISO / COMP / FILTER。
///
/// EV100 列范围 -3..20（24 档整数）。其它列源数据：
/// [IsoValue.thirdStops] / [EvStop.values] / [NdFilter.values]。
class QuickDrum extends StatefulWidget {
  const QuickDrum({
    super.key,
    required this.ev100,
    required this.iso,
    required this.comp,
    required this.filter,
    required this.onEv100Changed,
    required this.onIsoChanged,
    required this.onCompChanged,
    required this.onFilterChanged,
  });

  final int ev100;
  final IsoValue iso;
  final EvStop comp;
  final NdFilter filter;

  final ValueChanged<int> onEv100Changed;
  final ValueChanged<IsoValue> onIsoChanged;
  final ValueChanged<EvStop> onCompChanged;
  final ValueChanged<NdFilter> onFilterChanged;

  static const int evMin = -3;
  static const int evMax = 20;

  @override
  State<QuickDrum> createState() => _QuickDrumState();
}

class _QuickDrumState extends State<QuickDrum> {
  late final FixedExtentScrollController _evCtrl;
  late final FixedExtentScrollController _isoCtrl;
  late final FixedExtentScrollController _compCtrl;
  late final FixedExtentScrollController _filterCtrl;

  late List<int> _evList;
  late List<IsoValue> _isoList;
  late List<EvStop> _compList;
  late List<NdFilter> _filterList;

  @override
  void initState() {
    super.initState();
    _evList = [for (var i = QuickDrum.evMin; i <= QuickDrum.evMax; i++) i];
    _isoList = IsoValue.thirdStops;
    _compList = EvStop.values;
    _filterList = NdFilter.values;

    _evCtrl = FixedExtentScrollController(
      initialItem: _evList.indexOf(widget.ev100).clamp(0, _evList.length - 1),
    );
    _isoCtrl = FixedExtentScrollController(
      initialItem: _isoIndex(widget.iso),
    );
    _compCtrl = FixedExtentScrollController(
      initialItem:
          _compList.indexOf(widget.comp).clamp(0, _compList.length - 1),
    );
    _filterCtrl = FixedExtentScrollController(
      initialItem: widget.filter.index,
    );
  }

  int _isoIndex(IsoValue v) {
    final idx = _isoList.indexWhere((x) => x.value == v.value);
    return idx < 0 ? 0 : idx;
  }

  @override
  void didUpdateWidget(covariant QuickDrum old) {
    super.didUpdateWidget(old);
    _maybeJump(_evCtrl, _evList.indexOf(widget.ev100));
    _maybeJump(_isoCtrl, _isoIndex(widget.iso));
    _maybeJump(_compCtrl, _compList.indexOf(widget.comp));
    _maybeJump(_filterCtrl, widget.filter.index);
  }

  void _maybeJump(FixedExtentScrollController c, int target) {
    if (target < 0) return;
    if (c.selectedItem == target) return;
    c.animateToItem(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _evCtrl.dispose();
    _isoCtrl.dispose();
    _compCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // 中心高亮带
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                height: _itemExtent,
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
              child: _Column(
                label: 'EV100',
                controller: _evCtrl,
                count: _evList.length,
                builder: (i) => _evList[i].toString(),
                onSelected: (i) => widget.onEv100Changed(_evList[i]),
              ),
            ),
            Expanded(
              child: _Column(
                label: 'ISO',
                controller: _isoCtrl,
                count: _isoList.length,
                builder: (i) => _isoList[i].value.toString(),
                onSelected: (i) => widget.onIsoChanged(_isoList[i]),
              ),
            ),
            Expanded(
              child: _Column(
                label: 'COMP',
                controller: _compCtrl,
                count: _compList.length,
                builder: (i) => _compList[i].display,
                onSelected: (i) => widget.onCompChanged(_compList[i]),
              ),
            ),
            Expanded(
              child: _Column(
                label: 'FILTER',
                controller: _filterCtrl,
                count: _filterList.length,
                builder: (i) => _filterList[i].display,
                onSelected: (i) => widget.onFilterChanged(_filterList[i]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.label,
    required this.controller,
    required this.count,
    required this.builder,
    required this.onSelected,
  });

  final String label;
  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) builder;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: _itemExtent,
            perspective: 0.001,
            diameterRatio: 100,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onSelected,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (context, i) => Center(
                child: Text(
                  builder(i),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
