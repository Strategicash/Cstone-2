import 'package:flutter/material.dart';

import '../models/user_metrics.dart';

class GoalRow extends StatelessWidget {
  const GoalRow({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal.progress;
    final clamped = progress == null
        ? 0.0
        : progress.clamp(0.0, 100.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.title ?? 'Untitled goal',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (progress != null)
              Text(
                '${_fmt(progress)}%',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(0);
  }
}