import 'package:flutter/material.dart';

/// PR6 占位：完整快速测光视图在 PR7 落地。
class QuickMeterView extends StatelessWidget {
  const QuickMeterView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '快速测光\n（PR7 接入双列标尺 + 4 列滚轮）',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
