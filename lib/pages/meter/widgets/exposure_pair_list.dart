import 'package:film_go/domain/metering/ev_calculator.dart';
import 'package:film_go/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ExposurePairList extends StatelessWidget {
  const ExposurePairList({required this.pairs, super.key});

  final List<ExposurePair> pairs;

  @override
  Widget build(BuildContext context) {
    if (pairs.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('—')),
      );
    }
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pairs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final p = pairs[i];
          return Container(
            width: 88,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gray300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  p.aperture.display,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  p.shutter.display,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
