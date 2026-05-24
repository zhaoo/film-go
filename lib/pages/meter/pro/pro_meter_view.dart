import 'package:flutter/material.dart';

/// PR6 占位：完整专业测光视图在 PR8 落地。
class ProMeterView extends StatelessWidget {
  const ProMeterView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '专业测光\n（PR8 接入全屏取景 + 刻度尺 + 快门）',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
