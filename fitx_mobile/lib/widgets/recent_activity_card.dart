import 'package:flutter/material.dart';

import '../models/user_metrics.dart';

class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({
    super.key,
    required this.metrics,
    required this.onLogToday,
  });

  final UserMetrics metrics;
  final VoidCallback onLogToday;

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Recent Activity Placeholder'),
      ),
    );
  }
}