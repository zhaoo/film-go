import 'package:flutter/material.dart';

class CalcPage extends StatelessWidget {
  const CalcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Calc\n景深 / 超焦距 / 滤镜 / 互易律 / Sunny 16',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
