import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Pro 左下大字读数：上行快门、下行光圈。
class ProReadout extends StatelessWidget {
  const ProReadout({super.key, required this.pair});

  final ExposurePair? pair;

  @override
  Widget build(BuildContext context) {
    final shutter = pair?.shutter.display ?? '—';
    final aperture = pair?.aperture.display ?? '—';
    const style = TextStyle(
      color: AppColors.paperWhite,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: 0.5,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(shutter, style: style),
          const SizedBox(height: 4),
          Text(aperture, style: style),
        ],
      ),
    );
  }
}
