import 'package:flutter/material.dart';

class MeterPage extends StatelessWidget {
  const MeterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Meter\n取景测光将在 M1 实现',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
