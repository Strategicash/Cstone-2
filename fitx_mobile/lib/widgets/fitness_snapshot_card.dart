import 'package:flutter/material.dart';

import '../models/user_metrics.dart';
import '../theme/app_theme.dart';

/// Mini progress chart showing weight/trend snapshot.
/// Tapping navigates to the [AppSection.progress] screen.
class FitnessSnapshotCard extends StatelessWidget {
  const FitnessSnapshotCard({super.key, required this.metrics, required this.onTap});

  final UserMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: () => onTap(),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fitness Snapshot',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.trending_up, size: 20, color: AppColors.accent),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TrendTile(
                    label: 'Weight',
                    value: metrics.weightKg != null
                        ? '${_formatDouble(metrics.weightKg!)} kg'
                        : '—',
                    icon: Icons.pool,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  _TrendTile(
                    label: 'Streak',
                    value: _fmtStreak(metrics.streakDays),
                    icon: Icons.local_fire_department,
                    color: AppColors.accentSecondary,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Total:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${metrics.workoutsTotal ?? 0} workouts',
                    style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtStreak(int? value) {
    if (value == null) return '—';
    return value > 0 ? '$value days' : '—';
  }

  String _formatDouble(double v) {
    return v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  }
}

class _TrendTile extends StatelessWidget {
  const _TrendTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            right: BorderSide(color: color.withValues(alpha: 0.3), width: 2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}