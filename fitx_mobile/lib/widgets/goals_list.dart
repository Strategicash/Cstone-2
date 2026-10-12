import 'package:flutter/material.dart';

import '../models/user_metrics.dart';
import 'goal_row.dart';

class GoalsList extends StatelessWidget {
  const GoalsList({super.key, required this.metrics});

  final UserMetrics metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.goals.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goals', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final goal in metrics.goals)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GoalRow(goal: goal),
              ),
          ],
        ),
      ),
    );
  }
}