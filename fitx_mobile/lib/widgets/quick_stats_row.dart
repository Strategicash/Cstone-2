import 'package:flutter/material.dart';

import '../models/user_metrics.dart';
import '../theme/app_theme.dart';

/// Horizontal strip of 3 compact metric cards shown on the dashboard.
class QuickStatsRow extends StatelessWidget {
  const QuickStatsRow({super.key, required this.metrics});

  final UserMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'This Week',
          value: _fmtWorkouts(metrics.workoutsThisWeek),
          icon: Icons.calendar_today,
          color: AppColors.accent,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Streak',
          value: _fmtStreak(metrics.streakDays),
          icon: Icons.local_fire_department,
          color: AppColors.accentSecondary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Last Visit',
          value: _fmtLastVisit(metrics.lastVisit),
          icon: Icons.access_time,
          color: AppColors.accentSecondary,
        ),
      ],
    );
  }

  String _fmtWorkouts(int? value) {
    if (value == null) return '—';
    return value > 0 ? value.toString() : '0';
  }

  String _fmtStreak(int? value) {
    if (value == null) return '—';
    return value > 0 ? '$value day${value > 1 ? 's' : ''}' : '—';
  }

  String _fmtLastVisit(String? value) {
    if (value == null || value.isEmpty) return '—';
    return value;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(color: color.withValues(alpha: 0.3), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}