import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// 通用横向滚动刻度尺。
///
/// - `PageView.builder` + `viewportFraction = itemExtent / 可用宽`
/// - 中心三角指示器（spotHighlight）
/// - active item 字号/字重高亮
/// - 父层换 activeIndex → didUpdateWidget animateToPage
class HorizontalScale extends StatefulWidget {
  const HorizontalScale({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onIndexChanged,
    this.itemExtent = 56,
    this.height = 56,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onIndexChanged;
  final double itemExtent;
  final double height;

  @override
  State<HorizontalScale> createState() => _HorizontalScaleState();
}

class _HorizontalScaleState extends State<HorizontalScale> {
  PageController? _ctrl;
  double? _builtForWidth;
  bool _syncing = false;

  int get _clamped => widget.activeIndex.clamp(0, widget.labels.length - 1);

  void _ensureController(double width) {
    if (_ctrl != null && _builtForWidth == width) return;
    // 保留用户当前滚动位置（旋转/parent rebuild 等微调宽度时不要跳回 activeIndex）
    final preserved = _ctrl?.hasClients == true
        ? (_ctrl!.page?.round() ?? _clamped)
        : _clamped;
    _ctrl?.dispose();
    final raw = widget.itemExtent / width;
    final vp = raw.clamp(0.15, 1.0);
    _ctrl = PageController(
      viewportFraction: vp.toDouble(),
      initialPage: preserved.clamp(0, widget.labels.length - 1),
    );
    _builtForWidth = width;
  }

  @override
  void didUpdateWidget(covariant HorizontalScale old) {
    super.didUpdateWidget(old);
    if (widget.labels.isEmpty) return;
    final c = _ctrl;
    if (c == null || !c.hasClients) return;
    final target = _clamped;
    final current = c.page?.round() ?? c.initialPage;
    if (_syncing || current == target) return;
    // 注意：父层在 200ms 内连续 push activeIndex 时，中间目标会被丢弃；
    // 调用者应限速，或等待动画完成后再触发下一次外部同步。
    _syncing = true;
    c
        .animateToPage(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        )
        .whenComplete(() {
      if (!mounted) return;
      _syncing = false;
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    if (_syncing) return;
    if (i == widget.activeIndex) return;
    widget.onIndexChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) {
      return SizedBox(height: widget.height);
    }
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          _ensureController(c.maxWidth);
          final active = _clamped;
          return Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _ctrl,
                onPageChanged: _onPageChanged,
                physics: const PageScrollPhysics(),
                itemCount: widget.labels.length,
                itemBuilder: (context, i) {
                  final on = i == active;
                  final style = TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: on ? 16 : 13,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w400,
                    color: on ? cs.onSurface : cs.onSurfaceVariant,
                  );
                  return Center(child: Text(widget.labels[i], style: style));
                },
              ),
              const IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: CustomPaint(
                      size: Size(12, 6),
                      painter: _DownTrianglePainter(AppColors.spotHighlight),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DownTrianglePainter extends CustomPainter {
  const _DownTrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _DownTrianglePainter old) => old.color != color;
}
